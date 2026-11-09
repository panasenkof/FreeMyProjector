package io.freemytv;

/** Pure-Java regression for the on-screen favorite shelf. No emulator or projector needed. */
public final class TestShelfSizing {
    private static void require(boolean value, String reason) {
        if (!value) throw new AssertionError(reason);
    }

    public static void main(String[] args) {
        final float available = 1760f, maximum = 270f, height = 126f;
        require(ShelfSizing.DEFAULT_ITEMS == 8, "original default");
        require(ShelfSizing.MAX_ITEMS == 12, "readability limit");
        float base = ShelfSizing.width(available, maximum, ShelfSizing.DEFAULT_ITEMS);
        require(Math.abs(base - 178f) < 0.01f, "eight apps preserve previous width");
        float previousWidth = Float.POSITIVE_INFINITY;
        for (int n = 1; n <= ShelfSizing.MAX_ITEMS; n++) {
            float tw = ShelfSizing.width(available, maximum, n);
            float gap = ShelfSizing.gap(n);
            float th = ShelfSizing.height(tw, base, height);
            float total = n * tw + (n - 1) * gap;
            require(tw > 0f && tw >= ShelfSizing.MIN_TILE_WIDTH,
                    "tile too small at count " + n + ": " + tw);
            require(th > 0f && th <= height, "invalid height for " + n + ": " + th);
            require(total <= available + 0.01f, "shelf overflows viewport at " + n);
            if (n >= 8) {
                require(tw <= previousWidth + 0.01f, "tile width grew unexpectedly at " + n);
            }
            if (n <= 8) require(Math.abs(gap - 48f) < 0.01f, "changed original spacing");
            if (n == 8) require(Math.abs(th - 126f) < 0.01f, "changed original height");
            previousWidth = tw;
        }
        float width12 = ShelfSizing.width(available, maximum, 12);
        require(width12 >= 120f && width12 < base, "12 apps must shrink but remain readable");
        require(ShelfSizing.width(available, maximum, 0) == 0f, "empty shelf");
        // Layout scales as one unit on 720p / 1080p: physical screen size affects all lengths.
        float k = 2f / 3f;
        require((width12 * k) > ShelfSizing.MIN_TILE_WIDTH * k, "720p normalized minimum");
        System.out.println("PASS shelf sizing: 1..12, no overflow, no scrolling, legible minimum");
    }
}
