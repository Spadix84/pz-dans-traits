package com.spadix84.dansclimate;

/**
 * Dan's Climate Control. ZombieBuddy runs main() when the mod loads, and applies the
 * {@code @Patch} classes by itself. They must sit in this package (javaPkgName in
 * mod.info) and not a subpackage: ZombieBuddy 2.3.4 compares the package name exactly
 * and skips any other without a word ("no patches in package ...").
 */
public class Main {
    public static final String VERSION = "0.1.0";

    public static void main(String[] args) {
        System.out.println("[DansClimate] " + VERSION + " loaded");
    }
}
