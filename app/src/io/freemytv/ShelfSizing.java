package io.freemytv;

/**
 * Pure layout arithmetic for the TV favorites shelf. It deliberately has no Android dependencies:
 * a normal JDK test can catch a layout regression without a projector or an emulator.
 */
final class ShelfSizing {
    private ShelfSizing() {}

    static final int DEFAULT_ITEMS = 8;
    static final int MAX_ITEMS = 12;
    /** Minimum icon width at the 1920x1080 reference scale; all dimensions scale together. */
    static final float MIN_TILE_WIDTH = 120f;
    private static final float REGULAR_GAP = 48f;
    private static final float COMPACT_GAP = 20f;

    /** Keep the previous 48px gap for up to eight apps; reduce spacing before shrinking icons too far. */
    static float gap(int count) {
        int compactSteps = Math.max(0, Math.min(MAX_ITEMS - DEFAULT_ITEMS, count - DEFAULT_ITEMS));
        return REGULAR_GAP - (REGULAR_GAP - COMPACT_GAP) * compactSteps / (MAX_ITEMS - DEFAULT_ITEMS);
    }

    static float width(float available, float maximum, int count) {
        if (count <= 0) return 0f;
        int n = Math.min(MAX_ITEMS, count);
        return Math.min(maximum, (available - (n - 1) * gap(n)) / n);
    }

    /** Shrink icon height proportionally to width, rather than distorting banners at 9-12 items. */
    static float height(float tileWidth, float standardTileWidth, float standardTileHeight) {
        if (standardTileWidth <= 0f) return 0f;
        return standardTileHeight * Math.min(1f, tileWidth / standardTileWidth);
    }
}
