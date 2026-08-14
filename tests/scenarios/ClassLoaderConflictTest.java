import java.io.IOException;
import java.io.InputStream;

public class ClassLoaderConflictTest {

    // Same binary name will be defined in two different class loaders.
    public static class Payload {
        @Override
        public String toString() {
            return "payload";
        }
    }

    static class ByteArrayClassLoader extends ClassLoader {
        ByteArrayClassLoader() {
            super(null); // isolate from app loader
        }

        Class<?> define(String name, byte[] bytes) {
            return defineClass(name, bytes, 0, bytes.length);
        }
    }

    public static void main(String[] args) throws Exception {
        String binaryName = Payload.class.getName();
        byte[] payloadBytes = readClassBytes(binaryName);

        ByteArrayClassLoader loaderA = new ByteArrayClassLoader();
        ByteArrayClassLoader loaderB = new ByteArrayClassLoader();

        Class<?> classA = loaderA.define(binaryName, payloadBytes);
        Class<?> classB = loaderB.define(binaryName, payloadBytes);

        Object a = classA.getDeclaredConstructor().newInstance();

        System.out.println("classA loader = " + classA.getClassLoader());
        System.out.println("classB loader = " + classB.getClassLoader());
        System.out.println("a.getClass()   = " + a.getClass());

        try {
            Object b = classB.cast(a);
            System.out.println(b.toString());
        } catch (ClassCastException ex) {
        }
    }

    private static byte[] readClassBytes(String binaryName) throws IOException {
        String resource = "/" + binaryName.replace('.', '/') + ".class";
        try (InputStream in = ClassLoaderConflictTest.class.getResourceAsStream(resource)) {
            if (in == null) {
                throw new IOException("Class bytes not found for " + resource);
            }
            return in.readAllBytes();
        }
    }
}