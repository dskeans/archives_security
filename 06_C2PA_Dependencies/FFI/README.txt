📦 arcHIVE FFI UniFFI Symbol Visibility Fix

This ZIP contains:
  - ✅ Correct module.modulemap
  - ✅ archive_c2pa_cli_ffiFFI.h (exposes all required UniFFI C symbols)
  - ✅ archive_c2pa_cli_ffi.swift (example Swift import)
  - ✅ Test.swift (uses imported C functions)
  - ✅ README.txt (you’re reading it)

──────────────────────────────────────────────
📁 Folder Structure:
──────────────────────────────────────────────
FFI_FIX/
├── archive_c2pa_cli_ffiFFI.h
├── archive_c2pa_cli_ffiFFI.modulemap
├── archive_c2pa_cli_ffi.swift
├── Test.swift
├── README.txt

──────────────────────────────────────────────
✅ How to Use This:
──────────────────────────────────────────────
1. Drop all files into:
   arcHIVE_Camera_App/FFI/

2. In Xcode target settings:
   - Header Search Paths:
     $(PROJECT_DIR)/arcHIVE_Camera_App/FFI
     ✅ Mark as recursive
   - Swift Compiler > Import Paths:
     $(PROJECT_DIR)/arcHIVE_Camera_App/FFI
   - Link Binary With Libraries:
     libarchive_c2pa_ffi.a

3. In your Swift file (e.g. archive_c2pa_cli_ffi.swift):
   import archive_c2pa_cli_ffiFFI

4. Build:
   Shift + Cmd + K → Clean
   Cmd + B → Build

──────────────────────────────────────────────
✅ Included Functions (visible from Swift):
──────────────────────────────────────────────
ffi_archive_c2pa_cli_ffi_uniffi_contract_version()
uniffi_archive_c2pa_cli_ffi_checksum_func_sign_file()
uniffi_archive_c2pa_cli_ffi_checksum_func_verify_file()

You’re good to go.
