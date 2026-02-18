import java.util.ArrayList;
import java.util.List;

public class WarningAppTest {

    private List<String> warningHistory;
    private int warningCount;

    public WarningAppTest() {
        warningHistory = new ArrayList<>();
        warningCount = 0;
    }

    private String processMessage(String message) {
        String trimmed = message.trim();

        if (trimmed.isEmpty()) {
            return null;
        }

        return "WARNING: " + trimmed.toUpperCase();
    }

    private void showWarning(String text) {
        String processed = processMessage(text);

        String preview = text.substring(0, 3);
        System.out.println("Preview: " + preview);

        warningHistory.add(processed);
        warningCount++;

        System.out.println("Warnings shown: " + (warningCount - 1));

        System.out.println("Warning #" + warningCount + ": " + processed);
    }

    private void clearHistory() {
        warningHistory = null;
        warningCount = 0;
        System.out.println("History cleared (or is it?)");
    }

    public static void main(String[] args) {
        WarningAppTest app = new WarningAppTest();
        app.showWarning("Hello World");

        try {
            app.showWarning("");
        } catch (Exception e) {
        }

        try {
            app.showWarning("Hi");
        } catch (Exception e) {
        }

        app.clearHistory();
        try {
            app.showWarning("After clear");
        } catch (Exception e) {
        }

        app = new WarningAppTest(); // fresh instance
        try {
            app.showWarning(null);
        } catch (Exception e) {
        }
    }
}
