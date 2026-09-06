// java: garbage collection, reachability, and the "leak by retention" pattern
import java.util.ArrayList;
import java.util.List;

public class MemoryDemo {

    static final int N = 200000;

    static long heapUsedMB() {
        Runtime rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
    }

    // objects become unreachable each iteration and are collected automatically
    static long churn() {
        long sum = 0;
        for (int i = 0; i < N; i++) {
            int[] block = new int[64];
            for (int j = 0; j < 64; j++) block[j] = i + j;
            sum += block[0];
            // no free call: block is unreachable after this iteration
        }
        return sum;
    }

    // java's version of a leak: objects stay reachable, so gc cannot reclaim them
    static List<int[]> retained = new ArrayList<>();
    static void retentionLeak(int blocks) {
        for (int i = 0; i < blocks; i++) {
            retained.add(new int[256]);   // still referenced by a live static field
        }
    }

    public static void main(String[] args) throws Exception {
        System.out.println("heap in use at start:      " + heapUsedMB() + " MB");

        long t0 = System.nanoTime();
        long s = churn();
        long t1 = System.nanoTime();
        System.out.println("churned " + N + " blocks, checksum " + s);
        System.out.println("elapsed: " + (t1 - t0) / 1_000_000 + " ms");
        System.out.println("heap in use after churn:   " + heapUsedMB() + " MB");

        System.gc();
        Thread.sleep(200);
        System.out.println("heap in use after System.gc(): " + heapUsedMB() + " MB");

        retentionLeak(20000);
        System.gc();
        Thread.sleep(200);
        System.out.println("heap after retaining 20000 blocks (post-gc): "
                           + heapUsedMB() + " MB");
        System.out.println("retained list size: " + retained.size()
                           + "  (still reachable, so not collectable)");

        retained.clear();
        System.gc();
        Thread.sleep(200);
        System.out.println("heap after clearing references (post-gc): "
                           + heapUsedMB() + " MB");
    }
}
