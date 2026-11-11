package com.spadix84.dansclimate;

import com.spadix84.dansclimate.ZoneModel.Env;
import com.spadix84.dansclimate.ZoneModel.Mode;
import com.spadix84.dansclimate.ZoneModel.Thermostat;
import com.spadix84.dansclimate.ZoneModel.Unit;
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
        ac.acs.add(new Unit(ZoneModel.AC_HIGH, ZoneModel.AC_SETPOINT));
        double cooled = ZoneModel.steadyState(ac, sunny);
        check(cooled < hot - 5, "the AC takes the heat off: " + cooled + " vs " + hot);
        check(cooled >= ZoneModel.AC_SETPOINT, "not below its setpoint: " + cooled);
        check(ac.terms[ZoneModel.AC] < 0, "the AC term cools");
        Zone coolDay = room();
        coolDay.acs.add(new Unit(ZoneModel.AC_HIGH, ZoneModel.AC_SETPOINT));
        ZoneModel.steadyState(coolDay, night);
        check(coolDay.terms[ZoneModel.AC] == 0, "an AC on a cold night does nothing");

        // Its dial and its fan: a higher setting stops sooner, low cools half as hard.
        Zone warm = room();
        warm.sunWindows = 1;
        warm.acs.add(new Unit(ZoneModel.AC_HIGH, 27));
        double to27 = ZoneModel.steadyState(warm, sunny);
        check(to27 >= 27 && to27 > cooled, "an AC set to 27 holds the room warmer: " + to27 + " vs " + cooled);
        Zone lowFan = room(), highFan = room();
        lowFan.sunWindows = highFan.sunWindows = 1;
        lowFan.t = highFan.t = 35;
        lowFan.acs.add(new Unit(ZoneModel.AC_LOW, 22));
        highFan.acs.add(new Unit(ZoneModel.AC_HIGH, 22));
        ZoneModel.rate(lowFan, sunny, 35, Double.NaN);
        ZoneModel.rate(highFan, sunny, 35, Double.NaN);
        near(lowFan.terms[ZoneModel.AC], -ZoneModel.AC_LOW, 1e-9, "low fan, a 20-tile room");
        near(highFan.terms[ZoneModel.AC], -ZoneModel.AC_HIGH, 1e-9, "high fan, a 20-tile room");
        Zone two = room();
        two.acs.add(new Unit(ZoneModel.AC_HIGH, 22));
        two.acs.add(new Unit(ZoneModel.AC_LOW, 22));
        ZoneModel.rate(two, sunny, 35, Double.NaN);
        near(two.terms[ZoneModel.AC], -(ZoneModel.AC_HIGH + ZoneModel.AC_LOW), 1e-9, "two units add up");

        // A space heater warms a cold room toward its setpoint, never past it.
        Env frost = env(-5, 3, 0, 0, 0);
        Zone den = room();
        double unheated = ZoneModel.steadyState(den, frost);
        den.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        double heated = ZoneModel.steadyState(den, frost);
        check(heated > unheated + 15 && heated <= 21, "the heater holds a cold room near 21: " + heated + " vs " + unheated);
        check(den.terms[ZoneModel.HEATER] > 0, "the heater term warms");
        Zone denLow = room();
        denLow.heaters.add(new Unit(ZoneModel.HEATER_LOW, 21));
        double onLow = ZoneModel.steadyState(denLow, frost);
        check(onLow > unheated + 10 && onLow <= heated, "low still warms the room: " + onLow + " vs " + heated);
        Zone bigHall = room();
        bigHall.area = 100;
        bigHall.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        check(ZoneModel.steadyState(bigHall, frost) < heated - 5, "one heater can't hold a hall");
        Zone hotRoom = room();
        hotRoom.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        ZoneModel.steadyState(hotRoom, sunny);
        check(hotRoom.terms[ZoneModel.HEATER] == 0, "a heater in a hot room does nothing");
        Zone both = room();
        both.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        both.acs.add(new Unit(ZoneModel.AC_HIGH, 24));
        double held = ZoneModel.steadyState(both, frost);
        check(held > 15 && held <= 21 && both.terms[ZoneModel.AC] == 0, "a heater and an AC with a gap between them don't fight");

        // Several thermostats in one room and a long step: still stable.
        Zone busy = room();
        busy.powered = true;
        busy.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        for (int i = 0; i < 4; i++) busy.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        busy.t = -5;
        ZoneModel.step(busy, frost, Double.NaN, 48);
        check(busy.t > 20 && busy.t <= 21.001, "four heaters and the building's heating settle: " + busy.t);

        // The player's furnace and central air conditioner, through vents. The grid is down
        // (powered is false): they don't need it.
        near(ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 1, 60), ZoneModel.CENTRAL_HEAT, 1e-9, "a small vented floor gets a furnace's full strength");
        near(ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 1, 240), ZoneModel.CENTRAL_HEAT / 2, 1e-9, "twice the floor it serves, half the heat each");
        near(ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 2, 240), ZoneModel.CENTRAL_HEAT, 1e-9, "a second furnace makes it up");
        check(ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 0, 60) == 0 && ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 1, 0) == 0,
            "nothing without a unit or a vent");
        Zone served = room();
        served.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        served.vents = 1;
        served.centralHeat = ZoneModel.CENTRAL_HEAT;
        double furnace = ZoneModel.steadyState(served, frost);
        check(furnace > 20.3 && furnace <= 21 && served.terms[ZoneModel.CENTRAL] > 0 && served.terms[ZoneModel.HVAC] == 0,
            "a furnace holds a vented room at the thermostat with the grid down: " + furnace);
        Zone noVent = room();
        noVent.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        noVent.centralHeat = ZoneModel.CENTRAL_HEAT;
        check(ZoneModel.steadyState(noVent, frost) < 5 && noVent.terms[ZoneModel.CENTRAL] == 0, "a room without a vent gets none of it");
        Zone thin = room();
        thin.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        thin.vents = 1;
        thin.centralHeat = ZoneModel.centralShare(ZoneModel.CENTRAL_HEAT, 1, 1200);
        double spread = ZoneModel.steadyState(thin, frost);
        check(spread < furnace - 3 && spread > ZoneModel.steadyState(noVent, frost), "one furnace over a huge floor only takes the edge off: " + spread);
        served.thermostat = new Thermostat(Mode.COOL, 21, 24);
        check(ZoneModel.steadyState(served, frost) < 5, "the thermostat on Cool: the furnace stays off");
        served.thermostat = new Thermostat(Mode.OFF, 21, 24);
        check(ZoneModel.steadyState(served, frost) < 5, "and off is off");
        Zone chilled = room();
        chilled.top = true;
        chilled.sunWindows = 3;
        chilled.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        chilled.vents = 2;
        chilled.centralCool = ZoneModel.CENTRAL_COOL;
        double aired = ZoneModel.steadyState(chilled, sunny);
        check(aired >= 24 && aired < 25.5 && chilled.terms[ZoneModel.CENTRAL] < 0, "central air holds a hot room near the cooling setpoint: " + aired);
        chilled.centralCool = 0;
        check(ZoneModel.steadyState(chilled, sunny) > aired + 2, "and without it the room bakes");
        check(ZoneModel.wantsHeat(new Thermostat(Mode.HEAT, 21, 24), 20) && !ZoneModel.wantsHeat(new Thermostat(Mode.COOL, 21, 24), 20)
            && ZoneModel.wantsCool(new Thermostat(Mode.AUTO, 21, 24), 25) && !ZoneModel.wantsCool(null, 25), "what the thermostat is asking for");
        served.thermostat = new Thermostat(Mode.AUTO, 21, 24);
        served.centralCool = ZoneModel.CENTRAL_COOL;
        served.heaters.add(new Unit(ZoneModel.HEATER_HIGH, 21));
        served.t = -5;
        ZoneModel.step(served, frost, Double.NaN, 48);
        check(served.t > 20 && served.t <= 21.001, "a furnace and a space heater together settle: " + served.t);

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
