package com.spadix84.dansclimate;

import com.spadix84.dansclimate.ZoneModel.Env;
import com.spadix84.dansclimate.ZoneModel.Mode;
import com.spadix84.dansclimate.ZoneModel.Thermostat;
import com.spadix84.dansclimate.ZoneModel.Zone;

/** Plain-Java tests of ZoneModel (no JUnit): run by tools/build.py --test. */
public class ZoneModelTest {
    static int passed;

    static void check(boolean ok, String what) {
        if (!ok) throw new AssertionError(what);
        passed++;
    }

    static void near(double got, double want, double tol, String what) {
        check(Math.abs(got - want) <= tol, what + ": got " + got + ", want " + want + " +/- " + tol);
    }

    static Env env(double tOut, double tGround, double daylight, double cloud, double wind) {
        Env e = new Env();
        e.tOut = tOut;
        e.tGround = tGround;
        e.daylight = daylight;
        e.cloud = cloud;
        e.windKph = wind;
        return e;
    }

    /** A 20-tile ground-floor room in a house, shut, no heating or cooling. */
    static Zone room() {
        Zone z = new Zone(1);
        z.thermostat = null;
        return z;
    }

    public static void main(String[] args) {
        // Passive, at night: the walls and the ground pull it to their weighted mean.
        Zone z = room();
        Env night = env(0, 10, 0, 0, 0);
        near(ZoneModel.steadyState(z, night), (0.08 * 0 + 0.02 * 10) / 0.10, 1e-6, "passive steady state");

        // Lag: a house at 30 C on a 10 C night loses about 2 C in the first hour, not all of it.
        z.t = 30;
        ZoneModel.step(z, env(10, 10, 0, 0, 0), Double.NaN, 1);
        near(z.t, 10 + 20 * Math.exp(-0.10), 0.05, "an hour's cooling follows the time constant");

        // A long step stays stable and lands on the steady state.
        z.t = 30;
        ZoneModel.step(z, night, Double.NaN, 500);
        near(z.t, 2, 0.01, "a long step settles without blowing up");

        // Heating holds a winter house near its setpoint.
        Zone h = room();
        h.powered = true;
        h.thermostat = new Thermostat(Mode.HEAT, 21, 24);
        double winter = ZoneModel.steadyState(h, env(-10, 2, 0, 0, 0));
        check(winter > 20.3 && winter <= 21, "heating holds the setpoint: " + winter);
        check(h.terms[ZoneModel.HVAC] > 0, "the heating term is on");

        // Without power it does nothing.
        h.powered = false;
        check(ZoneModel.steadyState(h, env(-10, 2, 0, 0, 0)) < 0, "no power, no heating");

        // Thermostat off: nothing either.
        h.powered = true;
        h.thermostat = new Thermostat(Mode.OFF, 21, 24);
        check(ZoneModel.steadyState(h, env(-10, 2, 0, 0, 0)) < 0, "thermostat off, no heating");

        // Heat mode doesn't cool, cool mode doesn't heat.
        h.thermostat = new Thermostat(Mode.HEAT, 21, 24);
        check(ZoneModel.steadyState(h, env(35, 20, 1, 0, 0)) > 30, "heat mode leaves a hot day hot");
        h.thermostat = new Thermostat(Mode.COOL, 21, 24);
        check(ZoneModel.steadyState(h, env(-10, 2, 0, 0, 0)) < 0, "cool mode leaves a cold night cold");

        // Auto cools a hot afternoon down to the cooling setpoint.
        h.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        double summer = ZoneModel.steadyState(h, env(35, 20, 1, 0, 0));
        check(summer >= 24 && summer < 24.8, "auto cools to the cooling setpoint: " + summer);

        // A smashed-open house in a blizzard: the heating runs flat out and still loses.
        Zone drafty = room();
        drafty.powered = true;
        drafty.thermostat = Thermostat.DEFAULT;
        drafty.ventWindows = 4;
        drafty.ventDoors = 1;
        double blizzard = ZoneModel.steadyState(drafty, env(-20, 0, 0, 1, 40));
        near(drafty.terms[ZoneModel.HVAC], ZoneModel.HVAC_HEAT, 1e-6, "heating at full power");
        check(blizzard < 0, "an open house in a blizzard stays below freezing: " + blizzard);

        // Drafts: an open window brings a room to the outside faster.
        Zone shut = room(), open = room();
        open.ventWindows = 1;
        shut.t = open.t = 20;
        Env cold = env(0, 10, 0, 0, 20);
        ZoneModel.step(shut, cold, Double.NaN, 1);
        ZoneModel.step(open, cold, Double.NaN, 1);
        check(open.t < shut.t - 3, "an open window cools faster: " + open.t + " vs " + shut.t);

        // The sun: a top floor bakes, a basement stays cool.
        Env sunny = env(30, 15, 1, 0, 0);
        Zone top = room(), ground = room(), basement = room();
        top.level = 1;
        top.top = true;
        basement.level = -1;
        top.sunWindows = ground.sunWindows = 2;
        double tTop = ZoneModel.steadyState(top, sunny);
        double tGround = ZoneModel.steadyState(ground, sunny);
        double tBasement = ZoneModel.steadyState(basement, sunny);
        check(tTop > tGround && tGround > 30, "a sunny top floor is the hottest: " + tTop + " > " + tGround);
        check(tBasement < 20, "a basement is cool in summer: " + tBasement);
        Zone curtained = room();
        curtained.sunWindows = 2 * 0.3;
        check(ZoneModel.steadyState(curtained, sunny) < tGround, "curtains keep the sun out");

        // Cloud takes most of the sun away.
        near(env(0, 0, 1, 1, 0).sun(), 0.3, 1e-9, "full cloud leaves 30% of the sun");

        // A fire warms a room, more in a small one.
        Zone hall = room(), closet = room();
        hall.area = 60;
        closet.area = 6;
        hall.fires = closet.fires = 1;
        check(ZoneModel.steadyState(closet, night) > ZoneModel.steadyState(hall, night) + 10, "a fire warms a closet more");

        // A window AC cools a hot room toward 22 C but never below it.
        Zone ac = room();
        ac.sunWindows = 1;
        double hot = ZoneModel.steadyState(ac, sunny);
        ac.acUnits = 1;
        double cooled = ZoneModel.steadyState(ac, sunny);
        check(cooled < hot - 5, "the AC takes the heat off: " + cooled + " vs " + hot);
        check(cooled >= ZoneModel.AC_SETPOINT, "not below its setpoint: " + cooled);
        check(ac.terms[ZoneModel.AC] < 0, "the AC term cools");
        Zone coolDay = room();
        coolDay.acUnits = 1;
        ZoneModel.steadyState(coolDay, night);
        check(coolDay.terms[ZoneModel.AC] == 0, "an AC on a cold night does nothing");

        // Rooms in a building pull together.
        Zone a = room(), b = room();
        a.t = 30;
        b.t = 10;
        ZoneModel.step(a, night, 20, 1);
        ZoneModel.step(b, night, 20, 1);
        check(a.terms[ZoneModel.MIX] < 0 && b.terms[ZoneModel.MIX] > 0, "mixing evens the rooms out");

        // The ground follows the air slowly.
        near(ZoneModel.groundStep(10, 30, 24), 10 + 20 * (1 - Math.exp(-1.0 / 30)), 1e-9, "a day moves the ground a little");

        // The cooling setpoint can't sit below the heating one.
        check(new Thermostat(Mode.AUTO, 25, 20).cool == 25, "cooling setpoint raised to the heating one");

        System.out.println("ZoneModelTest: " + passed + " checks passed");
    }
}
