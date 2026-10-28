#include <jni.h>
#include <stdint.h>
#include <string.h>
extern char *taima_normalize(const uint8_t *bytes, intptr_t count);
extern void taima_free(char *pointer);
JNIEXPORT jbyteArray JNICALL Java_nl_taima_NativeBridge_normalize(JNIEnv *env, jobject self, jbyteArray input) {
    (void) self;
    jsize count = (*env)->GetArrayLength(env, input);
    jbyte *bytes = (*env)->GetByteArrayElements(env, input, NULL);
    if (!bytes) return NULL;
    char *result = taima_normalize((const uint8_t *)bytes, count);
    (*env)->ReleaseByteArrayElements(env, input, bytes, JNI_ABORT);
    if (!result) return NULL;
    jsize size = (jsize)strlen(result);
    jbyteArray output = (*env)->NewByteArray(env, size);
    if (output) (*env)->SetByteArrayRegion(env, output, 0, size, (const jbyte *)result);
    taima_free(result);
    return output;
}
extern double taima_core_batch_ns(const uint8_t *bytes, intptr_t count, intptr_t iterations);
JNIEXPORT jdouble JNICALL Java_nl_taima_NativeBridge_coreBatch(JNIEnv *env, jobject self, jbyteArray input, jint iterations) {
    (void) self;
    jsize count = (*env)->GetArrayLength(env, input);
    jbyte *bytes = (*env)->GetByteArrayElements(env, input, NULL);
    if (!bytes) return -1;
    double result = taima_core_batch_ns((const uint8_t *)bytes, count, iterations);
    (*env)->ReleaseByteArrayElements(env, input, bytes, JNI_ABORT);
    return result;
}
