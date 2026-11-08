#!/usr/bin/env python3
"""Separate stale native element reads from actions whose effects are unknown.

No network/device is opened by this module. Inject a session-scoped transport
returning Reply and a *live*, read-only scene fingerprint callback (session,
target bundle/PID and orientation), rejecting an unexpected target first.
Raw response payloads belong only in a
private evidence directory. A successful command response is not its effect.
"""
from dataclasses import dataclass
import json
import math
import re
import time


@dataclass(frozen=True)
class Reply:
    status: int
    body: bytes


class WDAResponseError(RuntimeError):
    def __init__(self, status, code, private_payload):
        self.status = status
        self.code = code
        self.private_payload = private_payload
        # WDA messages may embed the entire SpringBoard tree. Never print them.
        super().__init__(f"WDA HTTP {status}: {code}")


class ProtocolError(RuntimeError):
    pass


class SceneChanged(RuntimeError):
    pass


class SelectionError(RuntimeError):
    pass


class ObservationExpired(SelectionError):
    pass


class ActionUnconfirmed(RuntimeError):
    pass


def decode_reply(reply):
    try:
        result = json.loads(reply.body)
    except (ValueError, UnicodeError, TypeError) as error:
        raise ProtocolError("WDA response is not valid JSON") from error
    if not isinstance(result, dict) or 'value' not in result:
        raise ProtocolError("WDA response has no value envelope")
    value = result['value']
    code = value.get('error') if isinstance(value, dict) else None
    if reply.status != 200 or code or result.get('status', 0) != 0:
        # Only known protocol codes are retained in the printable exception.
        allowed = {'stale element reference', 'no such element',
                   'invalid session id', 'unknown error', 'invalid argument',
                   'invalid element state'}
        safe_code = code if isinstance(code, str) and code in allowed else 'unclassified error'
        raise WDAResponseError(reply.status, safe_code, result)
    return value


class GuardedWDA:
    """One scene, serial calls, bounded re-reads; no automatic action resend.

    After any action lacks independently verified effect, this instance blocks
    further actions. Recovery/cleanup belongs to the caller's outer finally;
    there is intentionally no automatic reset/reselection escape hatch.
    """
    def __init__(self, send, live_scene, record=lambda event: None, *, read_attempts=3,
                 clock=time.monotonic):
        if type(read_attempts) is not int or not 1 <= read_attempts <= 3:
            raise ValueError('read_attempts must be within 1..3')
        self.send, self.live_scene, self.record = send, live_scene, record
        self.read_attempts = read_attempts
        self.clock = clock
        self.action_blocked = False

    def _same_scene(self, expected):
        if self.live_scene() != expected:
            raise SceneChanged('Native scene changed; no further command sent')

    def _query(self, selector, scene):
        # POST /elements is explicitly read-only despite its HTTP method.
        # Do not expose generic POST retry: click/actions/session are mutations.
        for attempt in range(1, self.read_attempts + 1):
            self._same_scene(scene)
            try:
                value = decode_reply(self.send('/elements', selector))
            except WDAResponseError as error:
                self.record({'operation': 'elementQuery', 'attempt': attempt,
                             'status': error.status, 'error': error.code})
                if (error.status == 404 and error.code == 'stale element reference'
                        and attempt < self.read_attempts):
                    continue
                raise
            if not isinstance(value, list) or not all(isinstance(x, dict) for x in value):
                raise ProtocolError('Native element query must return an element list')
            self.record({'operation': 'elementQuery', 'attempt': attempt,
                         'status': 200, 'matches': len(value)})
            return value

    def query_elements(self, selector):
        return self._query(selector, self.live_scene())

    def click_unique(self, selector, verify_effect, *, max_observation_age_seconds=None,
                     validate_target=None):
        """Click once, optionally rejecting an aged selection before dispatch.

        The age starts before selection, including stale query retries, optional
        read-only target validation, scene checks and the dispatch recorder.
        Freshness cannot guarantee a transient control stays present during input.
        It is never independent evidence of the action's effect.
        """
        if self.action_blocked:
            raise ActionUnconfirmed('Previous action unconfirmed; further actions blocked')
        if not callable(verify_effect):
            raise TypeError('Independent effect verification callback is required')
        budget = max_observation_age_seconds
        if budget is not None and (type(budget) not in (int, float)
                or not math.isfinite(budget) or not 0 < budget <= 2):
            raise ValueError('Observation age budget must be within 0..2 seconds')
        if validate_target is not None and not callable(validate_target):
            raise TypeError('Target validation must be a read-only callback')
        scene = self.live_scene()
        started = self.clock() if budget is not None else None

        def check_age():
            if budget is None:
                return
            age = self.clock() - started
            if not math.isfinite(age) or age < 0 or age >= budget:
                raise ObservationExpired('Native selection expired; no action sent')
            return age

        elements = self._query(selector, scene)
        if len(elements) != 1:
            raise SelectionError('Expected one current native element; no action sent')
        element = elements[0]
        key = element.get('ELEMENT') or element.get('element-6066-11e4-a52e-4f735466cecf')
        if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:-]*', key):
            raise ProtocolError('Native element ID missing or invalid; no action sent')
        check_age()
        if validate_target is not None and validate_target(key) is not True:
            raise SelectionError('Current target validation failed; no action sent')
        self._same_scene(scene)
        check_age()
        # Set the fence BEFORE sending: timeouts can occur after execution.
        self.action_blocked = True
        self.record({'operation': 'nativeAction', 'state': 'sendingOnce'})
        try:
            # A slow evidence sink must not turn a fresh selection into stale input.
            dispatch_age = check_age()
        except ObservationExpired:
            self.action_blocked = False  # No mutation was dispatched.
            self.record({'operation': 'nativeAction', 'state': 'observationExpiredBeforeDispatch'})
            raise
        age_metrics = ({} if budget is None else {
            'selectionAgeAtDispatchSeconds': dispatch_age,
            'maximumObservationAgeSeconds': budget})
        try:
            decode_reply(self.send('/element/' + key + '/click', {}))
        except Exception as error:
            self.record({'operation': 'nativeAction', 'state': 'unconfirmed',
                         'failureType': type(error).__name__, **age_metrics})
            raise ActionUnconfirmed('Native action response unconfirmed; not resent') from error
        self.record({'operation': 'nativeAction', 'state': 'responseReceivedEffectUnknown',
                     **age_metrics})
        try:
            verified = verify_effect()
        except Exception as error:
            self.record({'operation': 'nativeAction', 'state': 'effectUnconfirmed',
                         'failureType': type(error).__name__})
            raise ActionUnconfirmed('Native action effect could not be verified') from error
        if verified is not True:
            self.record({'operation': 'nativeAction', 'state': 'effectUnconfirmed'})
            raise ActionUnconfirmed('Native action effect unverified; further actions blocked')
        self.record({'operation': 'nativeAction', 'state': 'effectVerifiedByCaller'})
        self.action_blocked = False
