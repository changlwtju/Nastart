/* Nastart: MobileVLCKit ships and exports its own, different build of libsmb2. A linker binds an
 * undefined symbol to the first library that exports it, so calling these under their upstream
 * names reached VLC's copy with this copy's context and crashed. Every function Nastart calls is
 * renamed; keep this list in step with what NetworkMedia calls.
 * `nm -m Nastart.debug.dylib | grep 'smb2.*MobileVLCKit'` must print nothing. */
#ifndef NASTART_SMB2_SYMBOLS_H
#define NASTART_SMB2_SYMBOLS_H
#define smb2_cmd_close_async nastart_smb2_cmd_close_async
#define smb2_cmd_create_async nastart_smb2_cmd_create_async
#define smb2_cmd_query_directory_async nastart_smb2_cmd_query_directory_async
#define smb2_cmd_read_async nastart_smb2_cmd_read_async
#define smb2_destroy_context nastart_smb2_destroy_context
#define smb2_free_data nastart_smb2_free_data
#define smb2_get_dialect nastart_smb2_get_dialect
#define smb2_get_fd nastart_smb2_get_fd
#define smb2_get_max_read_size nastart_smb2_get_max_read_size
#define smb2_get_nterror nastart_smb2_get_nterror
#define smb2_init_context nastart_smb2_init_context
#define smb2_queue_pdu nastart_smb2_queue_pdu
#define smb2_service nastart_smb2_service
#define smb2_set_domain nastart_smb2_set_domain
#define smb2_set_password nastart_smb2_set_password
#define smb2_set_security_mode nastart_smb2_set_security_mode
#define smb2_set_sign nastart_smb2_set_sign
#define smb2_set_timeout nastart_smb2_set_timeout
#define smb2_set_version nastart_smb2_set_version
#define smb2_share_enum_async nastart_smb2_share_enum_async
#define smb2_which_events nastart_smb2_which_events
#endif
