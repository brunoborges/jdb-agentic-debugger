/**
 * AttachDemo.java — 专为验证 jdb-breakpoints.sh attach 模式痛点而设计
 *
 * 痛点覆盖：
 *   1. 重载方法：process(String) vs process(String, int) — 触发"已重载方法"报错
 *   2. suspend=n 下断点命中只暂停当前线程 — where all 无法看到暂停线程
 *   3. 长时运行 HTTP-like 循环 — 允许 attach 后触发请求命中断点
 *
 * 启动方式：
 *   javac AttachDemo.java
 *   java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:15005 AttachDemo
 *
 * 然后用 attach 模式调试：
 *   jdb -attach localhost:15005
 */
public class AttachDemo {

    // ========== 重载方法组（痛点1：重载导致断点设置失败）==========
    public static String process(String input) {
        return "processed: " + input.toUpperCase();
    }

    public static String process(String input, int times) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < times; i++) {
            sb.append(input);
        }
        return "repeated: " + sb.toString();
    }

    public static String process(String input, boolean verbose) {
        if (verbose) {
            return "[VERBOSE] processing: " + input + " -> " + input.toUpperCase();
        }
        return process(input);
    }

    // ========== 业务逻辑（可触发断点的目标方法）==========
    public static void handleRequest(String payload) {
        // 这个方法是断点目标：无重载，断点容易设置
        String result1 = process(payload);           // 调用重载1
        String result2 = process(payload, 3);        // 调用重载2
        String result3 = process(payload, true);     // 调用重载3
        System.out.printf("[%s] results: %s | %s | %s%n",
            Thread.currentThread().getName(), result1, result2, result3);
    }

    // ========== 主循环（每秒处理一次，可随时 attach）==========
    public static void main(String[] args) throws Exception {
        System.out.println("AttachDemo started. JDWP listening...");
        System.out.println("Set breakpoint: stop in AttachDemo.handleRequest");
        System.out.println("Or test overload: stop in AttachDemo.process");
        System.out.println("Press Ctrl+C to stop.");
        System.out.println();

        String[] payloads = {"hello", "world", "jdb-test", "breakpoint"};
        int counter = 0;

        while (true) {
            String payload = payloads[counter % payloads.length];
            handleRequest(payload);
            counter++;
            Thread.sleep(2000);  // 每 2 秒触发一次，给 attach + 设断点留足时间
        }
    }
}

