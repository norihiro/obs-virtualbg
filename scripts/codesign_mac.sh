#! /bin/bash

pkg=build/obs-virtualbg-*.zip

mkdir codesign
unzip $pkg -d codesign

dylibs="$(find codesign -name '*.so')"

set +x # for code signing, hide itentity.
for dylib in "${dylibs[@]}"; do
  if test ! -f "$dylib"; then
    echo "Warning: File '$dylib' is not found."
    continue
  fi
  chmod +rw $dylib
  echo "=> Dependencies for $(basename $dylib)"
  otool -L $dylib
  if test -n "$MACOS_SIGNING_APPLICATION_IDENTITY"; then
    echo "=> Signing plugin binary: $dylib"
    codesign --sign "$MACOS_SIGNING_APPLICATION_IDENTITY" $dylib
  else
    echo "=> Skipped plugin codesigning since MACOS_SIGNING_APPLICATION_IDENTITY is not set"
  fi
done
shasum "${dylibs[@]}"

(cd codesign && zip -r ../${pkg} *)
