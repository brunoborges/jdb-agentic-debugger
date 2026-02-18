import java.util.ArrayList;

public class AliasingCorruptionTest {

    static class OrderLine {
        String product;
        int quantity;

        @Override
        public String toString() {
            return product + " x" + quantity;
        }
    }

    public static void main(String[] args) {
        var snapshot = new ArrayList<OrderLine>();

        OrderLine data = new OrderLine();

        String[] products = { "Keyboard", "Mouse", "Monitor" };
        int[] quantities = { 1, 2, 3 };

        for (int index = 0; index < products.length; index++) {
            data.product = products[index];
            data.quantity = quantities[index];
            snapshot.add(data);
        }

        for (int index = 0; index < snapshot.size(); index++) {
            OrderLine line = snapshot.get(index);
            System.out.println("[" + index + "] " + line + " (identity=" + System.identityHashCode(line) + ")");
        }
    }
}
