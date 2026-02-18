public class VisibilityTest {

    // Intentionally NOT volatile.
    private static boolean stopRequested = false;
    private static long counter = 0;

    public static void main(String[] args) throws Exception {
        Thread worker = new Thread(() -> {
            // Tight loop intentionally has no synchronization.
            while (!stopRequested) {
                counter++;
            }
            System.out.println("Worker observed stopRequested=true, counter=" + counter);
        }, "visibility-worker");

        worker.start();

        Thread.sleep(200); // let worker run / JIT warm a bit
        stopRequested = true;
        System.out.println("Main set stopRequested=true");

        worker.join(1000);

        if (worker.isAlive()) {
            worker.setDaemon(true);
        } else {
            System.out.println("No repro this run. Re-run several times for demonstration.");
        }
    }
}