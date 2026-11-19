import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;

/** Bounded Java4Shell regression: all writes stay within a real destination array. */
public final class Base64Regression {
    private static volatile int sink;

    public static void main(String[] args) {
        byte[] target = new byte[4096];
        for (Base64.Decoder decoder : new Base64.Decoder[] {
                Base64.getDecoder(), Base64.getUrlDecoder(), Base64.getMimeDecoder()}) {
            byte[] warmup = "A".repeat(256).getBytes(StandardCharsets.US_ASCII);
            for (int i = 0; i < 200_000; i++) {
                sink += decoder.decode(warmup, target);
            }

            for (int prefix : new int[] {64, 128, 256}) {
                for (String tail : new String[] {"=", "==", "A=", "A==", "AA=", "==="}) {
                    byte[] input = ("A".repeat(prefix) + tail).getBytes(StandardCharsets.US_ASCII);
                    Arrays.fill(target, (byte) 0x5a);
                    try {
                        decoder.decode(input, target);
                        throw new AssertionError("Accepted malformed padding: " + prefix + "/" + tail);
                    } catch (IllegalArgumentException expected) {
                        // Decoding may write a valid prefix before rejecting the malformed tail.
                    }
                    int outputLimit = (input.length / 4) * 3 + 3;
                    for (int i = outputLimit; i < target.length; i++) {
                        if (target[i] != (byte) 0x5a) {
                            throw new AssertionError("Base64 overwrite at " + i + ": " + prefix + "/" + tail);
                        }
                    }
                }
            }
        }

        byte[] original = new byte[1025];
        for (int i = 0; i < original.length; i++) {
            original[i] = (byte) i;
        }
        Base64.Encoder[] encoders = {Base64.getEncoder(), Base64.getUrlEncoder(), Base64.getMimeEncoder()};
        Base64.Decoder[] decoders = {Base64.getDecoder(), Base64.getUrlDecoder(), Base64.getMimeDecoder()};
        for (int i = 0; i < encoders.length; i++) {
            for (int length : new int[] {0, 1, 2, 3, 47, 48, 49, 95, 96, 97, 191, 192, 193, 1025}) {
                byte[] value = Arrays.copyOf(original, length);
                for (Base64.Encoder encoder : new Base64.Encoder[] {encoders[i], encoders[i].withoutPadding()}) {
                    byte[] encoded = encoder.encode(value);
                    int decoded = decoders[i].decode(encoded, target);
                    if (decoded != value.length || !Arrays.equals(value, Arrays.copyOf(target, decoded))) {
                        throw new AssertionError("Valid Base64 round trip failed: " + i + "/" + length);
                    }
                }
            }
        }
        System.out.println("Java4Shell regression passed: " + System.getProperty("java.runtime.version"));
    }
}
