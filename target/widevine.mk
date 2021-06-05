# Bundle Widevine DRM
WIDEVINE_PATH := $(dir $(LOCAL_PATH))proprietary/widevine/vendor

PRODUCT_COPY_FILES += \
    $(WIDEVINE_PATH)/bin/hw/android.hardware.drm@1.3-service.widevine:$(TARGET_COPY_OUT_VENDOR)/bin/hw/android.hardware.drm@1.1-service.widevine:widevine \
    $(WIDEVINE_PATH)/etc/init/android.hardware.drm@1.3-service.widevine.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.drm@1.1-service.widevine.rc:widevine

PRODUCT_PACKAGES += android.hardware.drm@1.3-service.widevine
