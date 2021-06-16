# Bundle Widevine DRM
WIDEVINE_PATH := $(dir $(LOCAL_PATH))proprietary/widevine/vendor

PRODUCT_PACKAGES += android.hardware.drm@1.3-service.widevine
