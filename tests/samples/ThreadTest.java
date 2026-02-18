import java.lang.management.ManagementFactory;
import java.lang.management.ThreadInfo;
import java.lang.management.ThreadMXBean;
import java.util.concurrent.CountDownLatch;

public class ThreadTest {

    private static final Object LOCK_A = new Object();
    private static final Object LOCK_B = new Object();

    public static void main(String[] args) throws Exception {
        CountDownLatch bothHaveFirstLock = new CountDownLatch(2);

        Thread t1 = new Thread(() -> {
            synchronized (LOCK_A) {
                bothHaveFirstLock.countDown();
                await(bothHaveFirstLock);
                synchronized (LOCK_B) {
                    System.out.println("t1 acquired both locks");
                }
            }
        }, "test-t1");

        Thread t2 = new Thread(() -> {
            synchronized (LOCK_B) {
                bothHaveFirstLock.countDown();
                await(bothHaveFirstLock);
                synchronized (LOCK_A) {
                    System.out.println("t2 acquired both locks");
                }
            }
        }, "test-t2");

        t1.start();
        t2.start();

        Thread.sleep(500);

        ThreadMXBean bean = ManagementFactory.getThreadMXBean();
        long[] ids = bean.findDeadlockedThreads();
        if (ids != null && ids.length > 0) {
            for (ThreadInfo info : bean.getThreadInfo(ids, true, true)) {
                System.out.println(info);
            }
        }
        
        t1.join();
        t2.join();
    }

    private static void await(CountDownLatch latch) {
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}