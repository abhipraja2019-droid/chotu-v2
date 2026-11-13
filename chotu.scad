// =====================================================================
//  CHOTU  -  3D-printable body for a DIY desk robot pet
//  Original design (inspired by the *idea* of Reachy Mini, not a copy)
//
//  Free software: OpenSCAD (https://openscad.org)
//  Units: millimetres.  World origin = centre of the table under Chotu.
//
//  HOW TO USE
//   1. Open this file in OpenSCAD. Press F5 to preview the whole robot.
//   2. To get one printable part, change `part` below (or use the
//      command line:  openscad -D 'part="torso"' -o torso.stl chotu.scad)
//   3. Measure YOUR parts with a ruler/calipers and fix the numbers in
//      the "REAL PART SIZES" section if they differ. Everything else
//      re-calculates by itself. That is what "parametric" means.
// =====================================================================

/* [Which part to show] */
// assembly | exploded | base_plate | base_shell | torso | head_platform | head_shell | antenna
part = "assembly"; // overridden by -D

$fn = 48;
eps = 0.01;

// ---------------------------------------------------------------------
//  REAL PART SIZES  (check these against your own parts!)
// ---------------------------------------------------------------------

// --- MG90S micro servo (servo's own coordinates: shaft at X=0,Y=0,
//     body runs along +X, bottom at Z=0, spline points up +Z)
sv_len      = 22.8;   // body length
sv_wid      = 12.2;   // body width
sv_shaft_x  = 6.1;    // shaft centre distance from the near end of body
sv_tab_z    = 18.0;   // height of the underside of the mounting tabs
sv_tab_t    = 2.5;    // tab thickness
sv_tab_span = 32.5;   // tab tip to tab tip
sv_hole_sp  = 27.8;   // distance between the two tab screw holes
sv_top_z    = 22.7;   // top of the main body
sv_dome_z   = 26.7;   // top of the round gear bump
sv_spline_z = 30.0;   // top of the output spline
sv_clear    = 0.4;    // extra gap around the body so it slides in

// --- servo horn (the plastic/metal arm that comes with the servo)
horn_r      = 14;     // shaft centre -> hole you put the ball stud in
ball_off    = 4.5;    // horn surface -> centre of the M3 ball

// --- Raspberry Pi 4B
pi_l = 85; pi_w = 56;             // board size
pi_holes = [[3.5,3.5],[61.5,3.5],[3.5,52.5],[61.5,52.5]]; // M2.5
pi_standoff_h = 5;

// --- PCA9685 16-ch servo board (Adafruit-style / common clone)
pca_l = 62.5; pca_w = 25.4;
pca_hole_dx = 55.9; pca_hole_dy = 19.0;  // hole spacing (measure clones!)

// --- Raspberry Pi Camera Module 3 Wide
cam_w = 25; cam_h = 24;            // board
cam_hole_dx = 21; cam_hole_dy = 12.5;
cam_lens_up = 2.5;     // lens centre above the centre of the hole pattern
cam_window_d = 13;     // hole for the lens barrel
cam_standoff = 6;      // board front face -> inside of head wall

// --- INMP441 I2S microphone breakout
mic_board = 14.5;

// --- MAX98357A I2S amplifier breakout
amp_l = 19.4; amp_w = 17.8;

// --- speaker: DFRobot FIT0502 enclosed 3W 8 ohm box
spk_l = 70; spk_w = 30; spk_h = 16;      // box size
spk_hole_dx = 63; spk_hole_dy = 24;      // its 4 screw holes

// --- lazy-susan bearing (square, 4 inch = 100 mm is common)
ls_size = 100;
ls_h    = 8;          // thickness of the bearing
ls_hole_inset_bottom = 6;   // bottom plate holes: distance in from corner (each axis)
ls_hole_inset_top    = 14;  // top plate holes
ls_screw_d = 3.4;     // M3 clearance

// --- power + wiring parts in the base
dcad_l = 28; dcad_w = 14;  // DC barrel-jack -> screw-terminal adapter
dcad_hole_d = 11;          // wall hole the 6 V plug goes through
dcad_z = 8.5;              // barrel centre height above the base plate top
usbc_w = 13; usbc_h = 8;   // wall slot for the Pi's USB-C power plug
bb_l = 47; bb_w = 35;      // 170-point mini breadboard

// ---------------------------------------------------------------------
//  DESIGN SIZES  (Chotu's shape - change for a different look)
// ---------------------------------------------------------------------
wall = 2.5;

// base (static, holds Pi + power + speaker)
base_r     = 79;
base_h     = 52;      // floor bottom -> deck top
deck_t     = 4;
plate_t    = 3;       // removable bottom plate

// torso (turns on the lazy-susan, holds the 6 head servos + PCA9685)
torso_r_bot = 74;
torso_r_top = 72;
torso_h     = 44;
floor_t     = 4;
hex_a       = 44;     // distance centre -> outer face of each servo wall
hex_t       = 4;      // servo wall thickness
sv_axis_z   = 32;     // servo shaft height above torso floor bottom

// Stewart head
plat_r   = 32;        // radius of the 6 head ball joints
home_h   = 55;        // ball-joint height above servo shafts (head "home")
pair_half_angle = 15; // each platform pair sits at 30 +/- this

// head
head_w = 100; head_d = 84; head_h = 66; head_r = 16;
plat_t = 4;           // head floor thickness
lug_drop = 6;         // ball centre is this far below head floor
ant_x = 28;           // antenna servo position (left/right)
ant_y = -2;

// ---------------------------------------------------------------------
//  DERIVED NUMBERS (don't edit, they follow from above)
// ---------------------------------------------------------------------
Z_DECK   = base_h;                    // deck top
Z_TORSO  = base_h + ls_h;             // torso floor bottom
Z_SHAFT  = Z_TORSO + sv_axis_z;       // servo shaft height (world)
Z_BALLP  = Z_SHAFT + home_h;          // platform ball centres (world)
Z_PLAT   = Z_BALLP + lug_drop;        // head floor bottom (world)

spline_r = hex_a + (sv_spline_z - sv_tab_z);  // radius of spline tip
ball_r_b = spline_r - 1 + ball_off;           // radius of the base balls
sv_body_mid = sv_len/2 - sv_shaft_x;          // shaft -> body centre

function face_ang(i) = 60*i;
function hdir(i)     = (i%2==0) ? -1 : 1;     // horn points this way (tangent)
// base ball (horn tip) at home, world coords
function B(i) = let(a=face_ang(i), u=hdir(i)*(sv_body_mid+horn_r), r=ball_r_b)
                [r*cos(a)-u*sin(a), r*sin(a)+u*cos(a), Z_SHAFT];
// platform ball, world coords at home
function P_ang(i) = (i%2==0) ? 60*i + 30 - pair_half_angle
                             : 60*(i-1) + 30 + pair_half_angle;
function P(i) = [plat_r*cos(P_ang(i)), plat_r*sin(P_ang(i)), Z_BALLP];
function dist(a,b) = norm(a-b);
rod_len = dist(B(0), P(0));

echo(str("ROD length centre-to-centre = ", rod_len, " mm"));
for (i=[0:5]) echo(str("servo ", i, "  B=", B(i), "  P=", P(i)));

// ---------------------------------------------------------------------
//  HELPERS
// ---------------------------------------------------------------------
module rrect(l, w, r, h) {           // rounded rectangle slab, centred
    hull() for (x=[-1,1], y=[-1,1])
        translate([x*(l/2-r), y*(w/2-r), 0]) cylinder(r=r, h=h);
}
module standoff(h, d=6, hole=2.2) {
    difference() { cylinder(d=d, h=h); translate([0,0,-eps]) cylinder(d=hole, h=h+1); }
}
module tape_pad(l, w) {              // flat pad + 2 zip-tie slots
    difference() {
        rrect(l+4, w+4, 2, 1.2);
        for (x=[-1,1]) translate([x*(l/2-2), 0, -eps]) cube([2, 4.5, 3], center=true);
    }
}

// servo dummy (for preview only), servo coordinates
module servo_dummy() {
    color("DodgerBlue") {
        translate([-sv_shaft_x, -sv_wid/2, 0]) cube([sv_len, sv_wid, sv_top_z]);
        translate([sv_body_mid - sv_tab_span/2, -sv_wid/2, sv_tab_z]) cube([sv_tab_span, sv_wid, sv_tab_t]);
        cylinder(d=11.8, h=sv_dome_z);
    }
    color("White") cylinder(d=4.8, h=sv_spline_z);
}
// hole/cut-out a servo needs in a wall, servo coordinates
module servo_cut(depth=30) {
    translate([-sv_shaft_x - sv_clear, -sv_wid/2 - sv_clear, -depth])
        cube([sv_len + 2*sv_clear, sv_wid + 2*sv_clear, 2*depth]);
}
module servo_screw_holes(d=1.8, depth=20) {   // pilot holes for M2 self-tappers
    for (s=[-1,1]) translate([sv_body_mid + s*sv_hole_sp/2, 0, -depth]) cylinder(d=d, h=2*depth, $fn=16);
}

// =====================================================================
//  1. BASE PLATE  (removable bottom: Pi, speaker, amp, breadboard, DC jack)
// =====================================================================
pi_pos   = [-42.5, -61];       // Pi corner: USB-C/HDMI edge faces the back wall
spk_pos  = [0, 48];            // speaker box centre (fires DOWN through the plate)
bb_pos   = [0, 14.5];          // breadboard centre (under the yaw servo)
amp_pos  = [54, 15];           // amp centre
dcad_pos = [-58, 7];           // DC jack adapter centre (barrel points -x)
boss_ang = [45, 135, 225, 315];
boss_rad = base_r - wall - 4;
// stick 3-4 rubber bumper feet (5 mm+) under the plate so the speaker can breathe

module base_plate() {
    difference() {
        union() {
            cylinder(r=base_r - wall - 0.3, h=plate_t, $fn=120);
        }
        for (a=boss_ang) rotate(a) translate([boss_rad,0,-eps]) {
            cylinder(d=3.4, h=20);
            cylinder(d1=6.5, d2=3.4, h=1.8);   // countersink
        }
        // speaker grille + 4 screw holes
        translate([spk_pos[0], spk_pos[1], 0]) {
            for (x=[-24:4:24], y=[-8:4:8]) translate([x,y,-1]) cylinder(d=2.6, h=10, $fn=12);
            for (x=[-1,1], y=[-1,1]) translate([x*spk_hole_dx/2, y*spk_hole_dy/2, -1]) cylinder(d=2.2, h=10, $fn=12);
        }
        // rubber-feet marks
        for (a=[0,120,240]) rotate(a-90) translate([62,0,-eps]) cylinder(d=12.5, h=0.5);
        // airflow holes under the Pi
        for (x=[-30:10:30], y=[-50:10:-20]) translate([x,y,-eps]) cylinder(d=4, h=10, $fn=12);
    }
    // Pi standoffs
    for (h=pi_holes) translate([pi_pos[0]+h[0], pi_pos[1]+h[1], plate_t]) standoff(pi_standoff_h);
    // pads: breadboard, amp, DC jack adapter
    translate([bb_pos[0], bb_pos[1], plate_t]) tape_pad(bb_l, bb_w);
    translate([amp_pos[0], amp_pos[1], plate_t]) rotate(90) tape_pad(amp_l, amp_w);
    translate([dcad_pos[0], dcad_pos[1], plate_t]) tape_pad(dcad_l, dcad_w);
}

// =====================================================================
//  2. BASE SHELL  (wall + top deck; yaw servo hangs under the deck)
//     Print it UPSIDE DOWN (deck on the bed).
// =====================================================================
module base_shell() {
    difference() {
        union() {
            difference() {
                cylinder(r=base_r, h=base_h, $fn=160);
                translate([0,0,-eps]) cylinder(r=base_r-wall, h=base_h-deck_t+eps, $fn=160);
            }
            // screw bosses for the bottom plate
            for (a=boss_ang) rotate(a) translate([boss_rad,0,plate_t]) {
                cylinder(d=8, h=base_h-deck_t-plate_t+eps);
                translate([0,-4,0]) cube([6,8,base_h-deck_t-plate_t+eps]);
            }
        }
        // left wall: hole for the 6 V barrel plug (DC jack adapter behind it)
        translate([-base_r-1, dcad_pos[1], plate_t+dcad_z]) rotate([0,90,0]) cylinder(d=dcad_hole_d, h=12);
        // back wall: slot for the Pi's USB-C power plug (lines up with the port)
        translate([pi_pos[0]+11.2, -base_r+3, plate_t+pi_standoff_h+1.6+1.6]) rotate([90,0,0])
            rrect(usbc_w, usbc_h, 2.5, 12);
        // vents: right side (over the Pi's USB/Ethernet end) and back
        for (a=[-55:7:-20]) rotate(a) translate([base_r-4, 0, 22]) cube([8, 2.6, 22], center=true);
        for (a=[-160:7:-120]) rotate(a) translate([base_r-4, 0, 22]) cube([8, 2.6, 22], center=true);
        // a "smile" of slots at the front
        for (a=[70:5:110]) rotate(a) translate([base_r-4, 0, 30 - 8*sin((a-70)*4.5)]) cube([8, 2.4, 9], center=true);
        // yaw servo through the deck (servo shaft at the centre)
        translate([0,0,base_h-deck_t]) {
            translate([-sv_shaft_x - sv_clear, -sv_wid/2 - sv_clear, -1])
                cube([sv_len + 2*sv_clear, sv_wid + 2*sv_clear, deck_t+2]);
            for (s=[-1,1]) translate([sv_body_mid + s*sv_hole_sp/2, 0, -1]) cylinder(d=2.3, h=deck_t+2, $fn=16); // M2 screw + nut
        }
        // cable hole through deck (camera ribbon, mic, servo power + I2C)
        translate([0, 15, base_h-deck_t-1]) rrect(22, 8, 2, deck_t+2);
        // lazy susan bottom-plate screw holes + pencil outline
        for (x=[-1,1], y=[-1,1])
            translate([x*(ls_size/2-ls_hole_inset_bottom), y*(ls_size/2-ls_hole_inset_bottom), base_h-deck_t-1])
                cylinder(d=ls_screw_d, h=deck_t+2, $fn=16);
        translate([0,0,base_h-0.6]) difference() {
            cube([ls_size+1, ls_size+1, 2], center=true); cube([ls_size-1, ls_size-1, 3], center=true);
        }
        // little "front" arrow so you know which way Chotu looks
        translate([0, base_r-10, base_h-0.6]) linear_extrude(1) polygon([[-5,0],[5,0],[0,6]]);
        // bottom-plate recess
        translate([0,0,-eps]) cylinder(r=base_r-wall+0.01, h=plate_t+eps, $fn=160);
        // screw holes in the bosses (self-tapping M3, 2.5 pilot)
        for (a=boss_ang) rotate(a) translate([boss_rad,0,-1]) cylinder(d=2.5, h=base_h-deck_t-2);
    }
}

// =====================================================================
//  3. TORSO  (turns on the bearing; 6 servos in a hex wall + PCA9685)
//     Print upright, floor on the bed.  Torso coordinates: z=0 is the
//     underside of its floor.
// =====================================================================
pca_pos = [0, -15];
module face_frame(i) {     // radial x, tangential y, z up
    rotate(face_ang(i)) children();
}
// servo i placed in torso coordinates
module torso_servo_place(i) {
    face_frame(i) translate([hex_a - sv_tab_z, hdir(i)*sv_body_mid, sv_axis_z])
        // servo Z -> +x radial ; servo X -> -hdir * y ; servo Y -> z
        multmatrix([[0,0,1,0],[-hdir(i),0,0,0],[0,1,0,0],[0,0,0,1]]) children();
}
module torso() {
    hex_h = sv_axis_z + sv_wid/2 + 4;
    difference() {
        union() {
            // floor
            cylinder(r=torso_r_bot, h=floor_t, $fn=160);
            // outer skirt (cosmetic shell, slightly tapered)
            difference() {
                cylinder(r1=torso_r_bot, r2=torso_r_top, h=torso_h, $fn=160);
                translate([0,0,floor_t]) cylinder(r1=torso_r_bot-wall, r2=torso_r_top-wall, h=torso_h, $fn=160);
            }
            // hex servo wall
            difference() {
                cylinder(r=hex_a/cos(30), h=hex_h, $fn=6);
                translate([0,0,-1]) cylinder(r=(hex_a-hex_t)/cos(30), h=hex_h+2, $fn=6);
            }
            // PCA9685 standoffs
            for (x=[-1,1], y=[-1,1]) translate([pca_pos[0]+x*pca_hole_dx/2, pca_pos[1]+y*pca_hole_dy/2, floor_t]) standoff(3, 5.5, 2.2);
            // 1000uF capacitor cradle next to the PCA9685 screw terminal
            translate([pca_pos[0]+pca_l/2-4, pca_pos[1]+pca_w/2+9, floor_t]) difference() {
                cylinder(d=14.5, h=8); translate([0,0,1]) cylinder(d=10.6, h=10);
            }
        }
        // servo openings + screw pilots in the hex wall
        for (i=[0:5]) torso_servo_place(i) { servo_cut(); servo_screw_holes(); }
        // yaw servo: centre screw access + 2 slots to screw the horn on
        translate([0,0,-1]) cylinder(d=7, h=floor_t+2);
        for (s=[-1,1]) hull() for (r=[6,15]) translate([s*r,0,-1]) cylinder(d=2.2, h=floor_t+2, $fn=12);
        // cable hole (same place as the one in the deck)
        translate([0, 15, -1]) rrect(22, 8, 2, floor_t+2);
        // lazy susan top-plate screw holes
        for (x=[-1,1], y=[-1,1])
            translate([x*(ls_size/2-ls_hole_inset_top), y*(ls_size/2-ls_hole_inset_top), -1]) cylinder(d=ls_screw_d, h=floor_t+2, $fn=16);
        // wire notch in the hex wall bottom (servo leads to the PCA9685)
        for (i=[0:5]) face_frame(i) translate([hex_a-2, 0, floor_t]) cube([8, 10, 6], center=true);
        // a smile cut in the front of the skirt (Chotu's "mouth" vent)
        translate([0,0,0]) rotate(90) for (a=[-20:5:20])
            rotate(a) translate([torso_r_bot-1, 0, 14 + 4*cos(a*4.5)*0]) cube([6, 2.4, 10], center=true);
    }
    // filler ring under the floor so the yaw horn sits snugly
    translate([0,0,-1]) difference() { cylinder(r=17, h=1); translate([0,0,-1]) cylinder(d=9, h=3); }
}

// =====================================================================
//  4. HEAD PLATFORM  (head floor + 6 ball-joint lugs + antenna towers)
//     Head coordinates: z=0 is the underside of the head floor.
//     Print it FLIPPED (lugs pointing up, towers down)? No: the towers
//     are tall, so print towers UP and add supports under the 6 lugs.
// =====================================================================
cam_lens_z = 30;   // lens height above head floor top
module head_outline(h) { rrect(head_w, head_d, head_r, h); }
module ant_servo_place(s) {   // s = -1 left, +1 right; servo coords, spline up
    translate([s*ant_x, ant_y, plat_t + head_h - sv_spline_z + 2.0]) rotate(-90) children();
}
module head_platform() {
    tower_top = plat_t + head_h - sv_spline_z + 2.0 + sv_tab_z;  // tab underside
    difference() {
        union() {
            head_outline(plat_t);
            // ball-joint lugs hanging down
            for (i=[0:5]) rotate(P_ang(i)) translate([plat_r-4-2, 0, -lug_drop-4])
                translate([-2,-4,0]) cube([4, 8, lug_drop+4+eps]);
            // antenna servo towers
            for (s=[-1,1]) ant_servo_place(s) translate([0,0,-(tower_top - plat_t) + sv_tab_z])
                difference() {
                    translate([sv_body_mid - sv_tab_span/2 - 1.5, -sv_wid/2 - 3, 0])
                        cube([sv_tab_span+3, sv_wid+6, tower_top-plat_t]);
                    translate([-sv_shaft_x - sv_clear, -sv_wid/2 - sv_clear, -1])
                        cube([sv_len + 2*sv_clear, sv_wid + 2*sv_clear, tower_top]);
                    // window to push the servo cable out
                    translate([sv_body_mid, 0, 4]) cube([10, 40, 8], center=true);
                }
        }
        // ball stud holes (M3, radial)
        for (i=[0:5]) rotate(P_ang(i)) translate([plat_r-12, 0, -lug_drop]) rotate([0,90,0]) cylinder(d=2.6, h=14, $fn=16);
        // antenna tower screw pilots
        for (s=[-1,1]) ant_servo_place(s) servo_screw_holes();
        // cable hole (ribbon + mic + antenna servo leads)
        translate([0, 6, -1]) rrect(22, 8, 2, plat_t+2);
        // head-shell screw holes
        for (x=[-1,1], y=[-1,1]) translate([x*(head_w/2-8.5), y*(head_d/2-8.5), -1]) {
            cylinder(d=3.4, h=plat_t+2, $fn=16);
            cylinder(d1=6.5, d2=3.4, h=1.8, $fn=16);
        }
    }
}

// =====================================================================
//  5. HEAD SHELL  (rounded "pill box" head, camera eye, mic hole,
//     antenna holes).  Head coordinates as above.
//     Print TOP-DOWN on the bed, with supports for the round edges.
// =====================================================================
module head_body(w, d, h, r) {
    hull() for (x=[-1,1], y=[-1,1]) {
        translate([x*(w/2-r), y*(d/2-r), 0]) cylinder(r=r, h=1);
        translate([x*(w/2-r), y*(d/2-r), h-r]) sphere(r);
    }
}
module head_shell() {
    z0 = plat_t;
    translate([0,0,z0]) difference() {
        union() {
            difference() {
                head_body(head_w, head_d, head_h, head_r);
                translate([0,0,-eps]) head_body(head_w-2*wall, head_d-2*wall, head_h-wall, head_r-wall);
            }
            // screw bosses
            for (x=[-1,1], y=[-1,1]) translate([x*(head_w/2-8.5), y*(head_d/2-8.5), 0]) cylinder(d=7, h=12);
            // camera standoffs (from inside of front wall, pointing back)
            translate([0, head_d/2 - wall, cam_lens_z]) rotate([90,0,0])
                for (x=[-1,1], y=[-1,1]) translate([x*cam_hole_dx/2, y*cam_hole_dy/2 - cam_lens_up, 0])
                    cylinder(d=4.5, h=cam_standoff);
            // mic frame under the top
            translate([0, -10, head_h-wall-2]) difference() {
                cube([mic_board+3, mic_board+3, 4], center=true);
                cube([mic_board+0.4, mic_board+0.4, 5], center=true);
            }
            // visor (cosmetic raised ring around the eye)
            translate([0, head_d/2 - 0.5, cam_lens_z]) rotate([-90,0,0]) cylinder(d1=30, d2=26, h=2.5);
        }
        // camera window (cone so the wide lens isn't blocked)
        translate([0, head_d/2 - wall - 0.5, cam_lens_z]) rotate([-90,0,0]) cylinder(d1=cam_window_d, d2=cam_window_d+10, h=wall+3.5);
        // camera standoff pilot holes (M2)
        translate([0, head_d/2 - wall + 0.5, cam_lens_z]) rotate([90,0,0])
            for (x=[-1,1], y=[-1,1]) translate([x*cam_hole_dx/2, y*cam_hole_dy/2 - cam_lens_up, 0])
                cylinder(d=1.8, h=cam_standoff+1, $fn=12);
        // mic sound hole
        translate([0, -10, head_h-wall-1]) cylinder(d=3, h=10, $fn=16);
        // antenna holes
        for (s=[-1,1]) translate([s*ant_x, ant_y, head_h-6]) cylinder(d=13.5, h=10);
        // screw pilots
        for (x=[-1,1], y=[-1,1]) translate([x*(head_w/2-8.5), y*(head_d/2-8.5), -1]) cylinder(d=2.5, h=10, $fn=16);
        // "breathing" slots at the back for cooling
        for (z=[15:6:40]) translate([0, -head_d/2, z]) cube([30, 6, 2.4], center=true);
    }
}

// =====================================================================
//  6. ANTENNA  (screw your servo's single-arm horn into the bottom)
// =====================================================================
module antenna() {
    difference() {
        union() {
            cylinder(d=12, h=6);
            // curved stalk
            translate([0,0,5]) for (k=[0:11]) hull() {
                t0 = k/12; t1 = (k+1)/12;
                translate([0, 18*t0*t0, 52*t0]) sphere(d=7 - 3*t0, $fn=20);
                translate([0, 18*t1*t1, 52*t1]) sphere(d=7 - 3*t1, $fn=20);
            }
            // tip "bobble"
            translate([0, 18, 57]) sphere(d=11, $fn=32);
        }
        // pocket for the horn hub + arm
        translate([0,0,-eps]) cylinder(d=7.4, h=4.5);
        translate([0,-3.1,-eps]) cube([16, 6.2, 2.2]);   // horn arm, 2.2 deep
        translate([0,0,-eps]) cylinder(d=2.6, h=20, $fn=12); // horn screw
    }
}

// =====================================================================
//  ASSEMBLY
// =====================================================================
module rod(a, b, d=3) { hull() { translate(a) sphere(d=d); translate(b) sphere(d=d); } }

module chotu(explode=0) {
    color("Gainsboro") translate([0,0,-explode*0.8]) base_plate();
    color("WhiteSmoke") base_shell();
    // Pi + parts (dummies)
    translate([0,0,-explode*0.8]) {
        color("Green") translate([pi_pos[0], pi_pos[1], plate_t+pi_standoff_h]) cube([pi_l, pi_w, 1.6]);
        color("Silver") translate([pi_pos[0]+pi_l-21, pi_pos[1]+2, plate_t+pi_standoff_h+1.6]) cube([21, 53, 16]);
        color("White") translate([bb_pos[0]-bb_l/2, bb_pos[1]-bb_w/2, plate_t+1.2]) cube([bb_l, bb_w, 8.5]);
        color("Purple") translate([amp_pos[0]-amp_w/2, amp_pos[1]-amp_l/2, plate_t+1.2]) cube([amp_w, amp_l, 3]);
        color("Black") translate([dcad_pos[0]-dcad_l/2, dcad_pos[1]-dcad_w/2, plate_t+1.2]) cube([dcad_l, dcad_w, 12]);
        color("Black") translate([spk_pos[0]-spk_l/2, spk_pos[1]-spk_w/2, plate_t]) cube([spk_l, spk_w, spk_h]);
    }
    // yaw servo (shaft up, centre)
    translate([0,0,Z_DECK - deck_t - sv_tab_z - sv_tab_t]) servo_dummy();
    // bearing
    color("DimGray", 0.8) translate([0,0,Z_DECK+explode*0.3]) difference() {
        translate([-ls_size/2, -ls_size/2, 0]) cube([ls_size, ls_size, ls_h]);
        translate([0,0,-1]) cylinder(d=60, h=ls_h+2);
    }
    // torso + its servos
    translate([0,0,Z_TORSO + explode*0.6]) {
        color("Orange") torso();
        for (i=[0:5]) torso_servo_place(i) servo_dummy();
        color("DarkBlue") translate([pca_pos[0]-pca_l/2, pca_pos[1]-pca_w/2, floor_t+3]) cube([pca_l, pca_w, 1.6]);
    }
    // rods (+ explode offset on the platform end)
    for (i=[0:5]) color("Silver") rod(B(i) + [0,0,explode*0.6], P(i) + [0,0,explode*1.2]);
    // head
    translate([0,0,Z_PLAT + explode*1.2]) {
        color("Orange") head_platform();
        for (s=[-1,1]) ant_servo_place(s) servo_dummy();
        color("ForestGreen") translate([0, head_d/2 - wall - cam_standoff - 1, plat_t + cam_lens_z]) rotate([90,0,0]) translate([-cam_w/2, -cam_h/2 - cam_lens_up, 0]) cube([cam_w, cam_h, 1]);
        color("WhiteSmoke", 1) translate([0,0,explode*0.6]) head_shell();
        for (s=[-1,1]) color("Orange") translate([s*ant_x, ant_y, plat_t + head_h + 2 + explode*0.8]) rotate(s*20) antenna();
    }
}

// =====================================================================
//  PICK WHAT TO RENDER
// =====================================================================
if (part == "assembly")       chotu(0);
else if (part == "exploded")  chotu(60);
else if (part == "base_plate") base_plate();
else if (part == "base_shell") translate([0,0,base_h]) rotate([180,0,0]) base_shell();   // print orientation
else if (part == "torso")      torso();
else if (part == "head_platform") translate([0,0,lug_drop+4]) head_platform(); // towers up, support the lugs
else if (part == "head_shell") translate([0,0,plat_t+head_h]) rotate([180,0,0]) head_shell(); // top on bed
else if (part == "antenna")    antenna();
