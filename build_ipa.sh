#!/bin/bash
#
# ShinnH4K — Build IPA (unsigned)
# Yêu cầu: macOS + Xcode 15+, xcodebuild, xcrun
#
set -euo pipefail

# ========== CẤU HÌNH ==========
PROJECT_NAME="ShinnH4K"
SCHEME_NAME="ShinnH4K"
BUNDLE_ID="com.apple.mobile.MobileHouseArrest"
BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
IPA_NAME="${PROJECT_NAME}.ipa"
# ==============================

echo "=================================================="
echo " SHINN H4K — IPA BUILD SCRIPT"
echo "=================================================="
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
    echo "[!] Script này phải chạy trên macOS."
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "[!] Không tìm thấy xcodebuild. Cài Xcode 15+ từ App Store."
    exit 1
fi

echo "[+] Xcode version:"
xcodebuild -version
echo ""

echo "[+] Dọn build cũ..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

if [[ ! -d "${PROJECT_NAME}.xcodeproj" ]]; then
    echo "[!] Không tìm thấy ${PROJECT_NAME}.xcodeproj"
    exit 1
fi

echo "[+] Bước 1/3: Archive (không ký)..."
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    | tee "${BUILD_DIR}/archive.log"

if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    echo "[!] Archive thất bại. Xem ${BUILD_DIR}/archive.log"
    exit 1
fi
echo "[+] Archive OK: ${ARCHIVE_PATH}"
echo ""

echo "[+] Bước 2/3: Export IPA (unsigned)..."

cat > "${BUILD_DIR}/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee "${BUILD_DIR}/export.log" || true

echo "[+] Bước 3/3: Đóng gói IPA unsigned thủ công..."

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
    echo "[!] Không tìm thấy .app trong archive."
    echo "    Kiểm tra: ${APP_PATH}"
    exit 1
fi

PAYLOAD_DIR="${BUILD_DIR}/Payload"
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"

rm -rf "${PAYLOAD_DIR}/${PROJECT_NAME}.app/_CodeSignature"
rm -f  "${PAYLOAD_DIR}/${PROJECT_NAME}.app/embedded.mobileprovision"

cd "${BUILD_DIR}"
zip -qr "${IPA_NAME}" "Payload"
cd ..

IPA_PATH="${BUILD_DIR}/${IPA_NAME}"
if [[ ! -f "${IPA_PATH}" ]]; then
    echo "[!] Không tạo được IPA."
    exit 1
fi

echo ""
echo "=================================================="
echo " ✅ BUILD THÀNH CÔNG"
echo "=================================================="
echo " IPA: ${IPA_PATH}"
echo " Size: $(du -h "${IPA_PATH}" | cut -f1)"
echo ""
echo " Bước tiếp theo:"
echo " 1. Ký bằng ESign/AltStore/Sideloadly với cert enterprise"
echo " 2. Hoặc: ldid -S ${PROJECT_NAME}.app (jailbreak device)"
echo ""
echo " LƯU Ý: Bundle ID = ${BUNDLE_ID}"
echo " Không đổi bundle ID nếu muốn MHA-C2 hoạt động."
echo ""