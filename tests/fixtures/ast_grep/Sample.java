// TODO: sample comment
import java.util.Optional;
import java.util.List;

class Widget {
    @Override
    public String toString() { return "a string"; }

    void draw(List<String> items) {
        System.out.println("x");
        Widget w = new Widget();
        if (w.equals(this)) {}
        Optional.of(w);
        items.stream().map(s -> s.trim());
        synchronized (this) {}
        for (String s : items) {}
        try {
            throw new RuntimeException("bad");
        } catch (RuntimeException e) {
            e.printStackTrace();
        }
    }
}
