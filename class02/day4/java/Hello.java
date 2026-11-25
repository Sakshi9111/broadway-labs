public class Main {
    static int square(int n) {
        return n * n;
    }

    public static void main(String[] args) {
        String name = "Asha";
        int age = 20;

        for (int i = 1; i <= 3; i++) {
            if (i % 2 == 0) {
                System.out.println(i + " is even");
            } else {
                System.out.println(i + " is odd");
            }
        }
        System.out.println(name + " squared age: " + square(age));
    }
}