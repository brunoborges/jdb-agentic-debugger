import java.util.Map;

public class ConsoleAppTest {

    public static void main(String[] args) {

        var discounts = Map.of(
                "BASIC", 5,
                "PREMIUM", 20,
                "VIP", 30);

        if (args.length == 0) {
            IO.println("Usage: java App <TIER>");
            return;
        }

        var tier = args[0];

        var discount = discounts.get(tier);

        if (discount == null) {
            discount = 0;
        }

        IO.println("Discount = " + discount + "%");
    }
}
