#!/usr/bin/env python3
"""Conservative native PiP pause evidence, never a movie/audio/pacing verdict.

No I/O or device actions. Snapshots must come from serial, private AFC + live WDA
observations around one guarded pause command. Old packages without the full
owner baseline/native command observation are deliberately insufficient.
"""
from dataclasses import dataclass, field
import json
import math
import re
from uuid import UUID

from wda_usb_session import NativePiPObservation, UIObservation


class InsufficientEvidence(RuntimeError):
    pass


TRANSITIONS = { 'diagnostics.playback.next.' + name for name in (
    'route_selected', 'resumed', 'seek_started', 'pip_started', 'pip_restore_requested',
    'pip_stopped', 'playback_stopped', 'playback_failed', 'playback_ended') }


@dataclass(frozen=True)
class Capture:
    started: float
    finished: float
    ui: UIObservation = field(repr=False)
    entries: tuple = field(repr=False)


def entries_from_preferences(preferences):
    try:
        rows = json.loads(preferences['diagnostics.entries.v1'])
    except (KeyError, ValueError, TypeError) as error:
        raise InsufficientEvidence('Diagnostic preference unavailable') from error
    if not isinstance(rows, list) or not rows or not all(isinstance(e, dict) for e in rows):
        raise InsufficientEvidence('Diagnostic entries unavailable')
    return tuple(rows)


def _number(value):
    if isinstance(value, bool):
        raise InsufficientEvidence('Invalid numeric evidence')
    try:
        result = float(value)
    except (ValueError, TypeError) as error:
        raise InsufficientEvidence('Numeric evidence missing') from error
    if not math.isfinite(result) or result < 0:
        raise InsufficientEvidence('Invalid numeric evidence')
    return result


def _uuid(value):
    try:
        return str(UUID(value)).upper()
    except (ValueError, TypeError, AttributeError) as error:
        raise InsufficientEvidence('Full owner identity unavailable') from error


def _details(row):
    # Relevant new observations contain scalar metrics, never comma-valued lists.
    raw = row.get('detail')
    if not isinstance(raw, str):
        raise InsufficientEvidence('Observation metrics missing')
    result = {}
    for part in raw.split(','):
        key, separator, value = part.strip().partition('=')
        if not separator or not key or key in result:
            raise InsufficientEvidence('Ambiguous observation metrics')
        result[key] = value.strip()
    return result


def _rows(capture):
    if not isinstance(capture, Capture) or not isinstance(capture.ui, (UIObservation, NativePiPObservation)):
        raise InsufficientEvidence('Live capture missing')
    if not (_number(capture.started) <= capture.ui.started <= capture.ui.finished
            <= _number(capture.finished)) or not capture.ui.png.startswith(b'\x89PNG\r\n\x1a\n'):
        raise InsufficientEvidence('Capture boundaries invalid')
    rows = {}
    last_date = -1
    for entry in capture.entries:
        if not isinstance(entry, dict):
            raise InsufficientEvidence('Malformed diagnostic entry')
        identity = entry.get('id')
        if not isinstance(identity, str) or not identity or identity in rows:
            raise InsufficientEvidence('Duplicate or missing event identity')
        date = _number(entry.get('date'))
        if date < last_date:
            raise InsufficientEvidence('Diagnostic order changed')
        rows[identity] = entry
        last_date = date
    if not rows:
        raise InsufficientEvidence('Empty diagnostic snapshot')
    return rows


def _baseline(before):
    rows = _rows(before)
    if before.ui.button_count('暂停') != 1 or before.ui.button_count('播放') != 0:
        raise InsufficientEvidence('Before state is not uniquely playing')
    starts = [e for e in rows.values() if e.get('messageKey') == 'diagnostics.playback.next.pip_started']
    if not starts:
        raise InsufficientEvidence('Current PiP baseline unavailable')
    metrics = _details(starts[-1])
    owner = _uuid(metrics.get('ownerPlanID'))
    trace, plan = metrics.get('playbackTraceID'), metrics.get('planID')
    if (not isinstance(trace, str) or not re.fullmatch(r'[0-9a-fA-F]{8}', trace)
            or not isinstance(plan, str) or plan.upper() != owner[:8]
            or metrics.get('enginePlaying') != 'true'):
        raise InsufficientEvidence('Full owner/playing baseline unavailable')
    uptime = _number(metrics.get('runtimeSnapshotUptime'))
    _number(metrics.get('currentSeconds'))
    if uptime <= 0:
        raise InsufficientEvidence('PiP baseline monotonic time unavailable')
    after_start = False
    for entry in rows.values():
        if entry is starts[-1]:
            after_start = True
            continue
        if not after_start:
            continue
        if entry.get('messageKey') in TRANSITIONS:
            raise InsufficientEvidence('PiP baseline was superseded by another transition')
        if entry.get('messageKey') == 'diagnostics.playback.next.pip_system_playback_changed':
            state = _details(entry)
            if _uuid(state.get('ownerPlanID')) != owner or state.get('actualPlaying') != 'true':
                raise InsufficientEvidence('Baseline engine state is no longer confirmed playing')
    return rows, metrics, owner, trace, plan, uptime


def require_pause_baseline(before):
    """Check before sending any pause, so an old package/cache cannot start a trial."""
    _baseline(before)


def assess_native_pause(before, first, held):
    """Raise on missing/ambiguous evidence; return a scoped proof on success.

    Scope: new engine command reports paused and native UI stays in paused state.
    This does not certify a continuously sampled stopped clock or rendered movie.
    Caller must retain all original captures and the single-action send record.
    """
    baseline, metrics, owner, trace, plan, baseline_uptime = _baseline(before)
    sets = [baseline, _rows(first), _rows(held)]
    for identity in sets[1].keys() & sets[2].keys():
        if sets[1][identity] != sets[2][identity]:
            raise InsufficientEvidence('Post-command event changed under the same identity')
    if not (before.finished < first.started and first.finished + 2 <= held.started):
        raise InsufficientEvidence('Need separated post-command observations over two seconds')
    if not (before.ui.scene == first.ui.scene == held.ui.scene):
        raise InsufficientEvidence('Native scene changed')
    for capture in (first, held):
        if capture.ui.button_count('播放') != 1 or capture.ui.button_count('暂停') != 0:
            raise InsufficientEvidence('Paused native control state not observed')
    baseline_rows = list(sets[0].values())
    # If the baseline tail falls out of the ring, absence of intervening events is unknown.
    tail = baseline_rows[-1]['id']
    for rows in sets[1:]:
        if tail not in rows or rows[tail] != sets[0][tail]:
            raise InsufficientEvidence('Diagnostic baseline lost or mutated')
        for identity in rows.keys() & sets[0].keys():
            if rows[identity] != sets[0][identity]:
                raise InsufficientEvidence('Persisted event changed under the same identity')
    new = {k: v for rows in sets[1:] for k, v in rows.items() if k not in sets[0]}
    native = [e for e in new.values() if e.get('messageKey') == 'diagnostics.playback.next.pip_system_playback_changed']
    if len(native) != 1 or native[0]['id'] not in sets[1] or native[0]['id'] not in sets[2]:
        raise InsufficientEvidence('Need exactly one new native playback observation in both captures')
    event = native[0]
    result = _details(event)
    if (_uuid(result.get('ownerPlanID')) != owner or result.get('playbackTraceID') != trace
            or result.get('planID', '').upper() != plan.upper()
            or result.get('requestedPlaying') != 'false' or result.get('actualPlaying') != 'false'
            or _number(result.get('snapshotUptime')) <= baseline_uptime
            or _number(event.get('date')) <= _number(baseline_rows[-1].get('date'))):
        raise InsufficientEvidence('Native command does not confirm this owner paused')
    observation_id = _uuid(result.get('observationID'))
    for old in baseline_rows:
        if old.get('messageKey') == 'diagnostics.playback.next.pip_system_playback_changed':
            if _uuid(_details(old).get('observationID')) == observation_id:
                raise InsufficientEvidence('Native observation token was already present')
    position = _number(result.get('currentSeconds'))
    if position < _number(metrics.get('currentSeconds')) - 0.1:
        raise InsufficientEvidence('Playback position moved backwards')
    for entry in new.values():
        if entry is event:
            continue
        name = entry.get('messageKey', '')
        if name in TRANSITIONS:
            raise InsufficientEvidence('Intervening playback transition makes this proof ambiguous')
    return {'nativePauseCommandObserved': True, 'fullOwnerMatched': True,
            'nativePausedUIObservationGapSeconds': held.started - first.finished,
            'nativeObservationCount': 1, 'continuouslyStoppedClockVerified': False,
            'restoredMovieVerified': False, 'audioVerified': False, 'framePacingVerified': False}
