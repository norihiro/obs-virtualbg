#! /bin/bash

CODESIGN_IDENT_SHORT=$(echo "${MACOS_SIGNING_APPLICATION_IDENTITY}" | /usr/bin/sed -En "s/.+\((.+)\)/\1/p")

ret=0

pkgs=(build/obs-virtualbg-*.zip)
uuids=()
for pkg in "${pkgs[@]}"; do
  echo "=> Submitting package $pkg for notarization"
  UPLOAD_RESULT=$(xcrun altool \
    --notarize-app \
    --primary-bundle-id "$MACOS_BUNDLEID" \
    --username "$MACOS_NOTARIZATION_USERNAME" \
    --password "$MACOS_NOTARIZATION_PASSWORD" \
    --asc-provider "$CODESIGN_IDENT_SHORT" \
    --file "$pkg")
  uuid=$(echo $UPLOAD_RESULT | awk -F ' = ' '/RequestUUID/ {print $2}')
  echo "Request UUID: $uuid"
  if test -z "$uuid"; then
    ret=1
  fi
  uuids=("${uuids[@]}" "$uuid")
  echo "$uuid $pkg" >> pkg_uuid
done

sleep 40
for uuid in "${uuids[@]}"; do
  pkg="$(grep "$uuid" < pkg_uuid | cut -d\  -f2-)"
  echo "Checking notarization status for package '$pkg' UUID=$uuid..."
  while sleep 10; do
    CHECK_RESULT=$(xcrun altool \
      --notarization-info "$uuid" \
      --username "$MACOS_NOTARIZATION_USERNAME" \
      --password "$MACOS_NOTARIZATION_PASSWORD" \
      --asc-provider "$CODESIGN_IDENT_SHORT")
    echo "$CHECK_RESULT"

    if ! grep -q "Status: in progress" <<< "$CHECK_RESULT"; then
      if grep -q 'Status: success' <<< "$CHECK_RESULT"; then
        if expr "$pkg" : '.*dmg$'; then
          echo "=> Staple ticket to installer: $pkg"
          xcrun stapler staple "$pkg"
        fi
      else
        ret=1
      fi
      break
    fi
  done
done

exit $ret
