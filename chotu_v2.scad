// =====================================================================
//  CHOTU v2  -  Reachy-Mini-style look, lighter
//
//  Look inspired by Pollen Robotics' Reachy Mini (their hardware design
//  is shared under CC BY-NC-SA). This is a personal, non-commercial
//  look-alike drawn from scratch around cheaper parts. Credit Pollen
//  Robotics if you share it, and don't sell it.
//
//  v2 re-uses v1's proven insides (chotu.scad): same base, bearing,
//  servo hexagon and head-joint geometry, so the head maths
//  (chotu_head_geometry.json) does not change.  What's new:
//   - tall bell-shaped BODY SHELL that hides the six head legs
//   - round "bean" HEAD with a black goggle VISOR and two big eyes
//     (the camera looks out of Chotu's left eye)
//   - slim antennas
//   - thinner walls + cut-outs everywhere to save weight
//
//  Usage:  openscad -D 'part="v2_assembly"' chotu_v2.scad
//  Parts:  v2_assembly | v2_exploded | base_plate | v2_base_shell |
//          v2_torso | v2_body_shell | v2_head_platform | v2_head_shell |
//          v2_visor | v2_antenna
// =====================================================================

include <chotu.scad>

part = "v2_assembly";

// ---------- v2 overrides (OpenSCAD uses the last value everywhere) ----
wall    = 1.8;     // thinner shells (was 2.5)
deck_t  = 4;
floor_t = 3;       // torso floor (was 4)
hex_t   = 3;       // servo hexagon wall (was 4)
plat_t  = 3;       // head floor (was 4)

head_w = 110; head_d = 80; head_h = 62; head_r = 22;   // round "bean" head

// ---------- v2 design sizes ----------
shell_wall  = 1.6;   // body shell wall
body_top_z  = 76;    // body shell top, measured from torso floor bottom
body_r_top  = 62;    // outer radius at the top of the body shell
rim_h       = 6;     // ring on the torso floor that the body shell slips over

eye_d   = 24;        // eye hole in the visor
eye_x   = 19;        // eyes sit at +/- this
eye_z   = 26;        // eye centre above the head floor top
vis_w   = 74; vis_h = 34; vis_t = 3.2;   // goggle visor
cam_lens_h = 12.4;   // Camera Module 3 Wide: board back -> lens front

// =====================================================================
//  TORSO v2: floor + servo hexagon + rim (no skirt; the body shell is
//  a separate light part).  Torso coordinates: z=0 = floor underside.
// =====================================================================
module v2_torso() {
    hex_h = sv_axis_z + sv_wid/2 + 4;
    difference() {
        union() {
            cylinder(r=torso_r_bot, h=floor_t, $fn=160);
            // rim the body shell slips over
            difference() {
                cylinder(r=torso_r_bot-shell_wall-0.2, h=floor_t+rim_h, $fn=160);
                translate([0,0,-1]) cylinder(r=torso_r_bot-shell_wall-0.2-2, h=floor_t+rim_h+2, $fn=160);
            }
            // servo hexagon
            difference() {
                cylinder(r=hex_a/cos(30), h=hex_h, $fn=6);
                translate([0,0,-1]) cylinder(r=(hex_a-hex_t)/cos(30), h=hex_h+2, $fn=6);
            }
            for (x=[-1,1], y=[-1,1]) translate([pca_pos[0]+x*pca_hole_dx/2, pca_pos[1]+y*pca_hole_dy/2, floor_t]) standoff(3, 5.5, 2.2);
            translate([pca_pos[0]+pca_l/2-4, pca_pos[1]+pca_w/2+9, floor_t]) difference() {
                cylinder(d=14.5, h=8); translate([0,0,1]) cylinder(d=10.6, h=10);
            }
        }
        for (i=[0:5]) torso_servo_place(i) { servo_cut(); servo_screw_holes(); }
        translate([0,0,-1]) cylinder(d=7, h=floor_t+2);
        for (s=[-1,1]) hull() for (r=[6,15]) translate([s*r,0,-1]) cylinder(d=2.2, h=floor_t+2, $fn=12);
        translate([0, 15, -1]) rrect(22, 8, 2, floor_t+2);
        for (x=[-1,1], y=[-1,1])
            translate([x*(ls_size/2-ls_hole_inset_top), y*(ls_size/2-ls_hole_inset_top), -1]) cylinder(d=ls_screw_d, h=floor_t+2, $fn=16);
        // weight-saving windows in the hexagon (also handy for wiring)
        for (i=[0:5]) face_frame(i) translate([hex_a-2, 0, floor_t+3]) rotate([0,90,0]) rrect(14, 24, 3, 10);
        // weight-saving holes in the floor, between the hexagon and the rim
        for (a=[0:60:300]) rotate(a) translate([60,0,-1]) cylinder(d=13, h=floor_t+2);
        // 3 screw pilots (M2) through the rim, for the body shell
        for (a=[90,210,330]) rotate(a) translate([torso_r_bot-8, 0, floor_t+rim_h/2]) rotate([0,90,0]) cylinder(d=1.6, h=10, $fn=12);
    }
    translate([0,0,-1]) difference() { cylinder(r=17, h=1); translate([0,0,-1]) cylinder(d=9, h=3); }
}

// =====================================================================
//  BODY SHELL v2: thin bell that hides the legs.  Print upright, no
//  supports (gentle overhang).  Torso coordinates.
// =====================================================================
function body_r(z) = let(t = (z - floor_t)/(body_top_z - floor_t))
                     body_r_top + (torso_r_bot - body_r_top) * (1 - pow(max(t,0), 1.8));
module v2_body_shell() {
    n = 24;
    pts_out = [for (k=[0:n]) let(z = floor_t + (body_top_z-floor_t)*k/n) [body_r(z), z]];
    pts_in  = [for (k=[n:-1:0]) let(z = floor_t + (body_top_z-floor_t)*k/n) [body_r(z)-shell_wall, z]];
    difference() {
        union() {
            rotate_extrude($fn=160) polygon(concat(pts_out, pts_in));
            // rounded lip on top
            translate([0,0,body_top_z]) rotate_extrude($fn=160) translate([body_r_top - shell_wall/2, 0]) circle(d=shell_wall*1.6, $fn=16);
        }
        // M2 screw holes into the torso rim
        for (a=[90,210,330]) rotate(a) translate([torso_r_bot-8, 0, floor_t+rim_h/2]) rotate([0,90,0]) cylinder(d=2.3, h=20, $fn=12);
        // small slot so the shell clears the body-turn cable path & vents
        for (a=[-25:10:25]) rotate(270+a) translate([torso_r_bot-3, 0, floor_t+20]) cube([10, 2.4, 14], center=true);
    }
}

// =====================================================================
//  HEAD v2.  Head coordinates: z=0 = underside of the head floor.
// =====================================================================
module pill(w, h, t) {     // goggle shape, standing up in the XZ plane, thickness along +y
    hull() for (s=[-1,1]) translate([s*(w/2-h/2), 0, 0]) rotate([-90,0,0]) cylinder(d=h, h=t, $fn=48);
}
head_boss = [[-50.6, 6], [50.6, 6], [-24, -35.6], [24, -35.6]];
module v2_head_platform() {
    tower_top = plat_t + head_h - sv_spline_z + 2.0 + sv_tab_z;
    cam_back_y = head_d/2 - wall - 4 - cam_lens_h;   // board back face
    difference() {
        union() {
            head_outline(plat_t);
            for (i=[0:5]) rotate(P_ang(i)) translate([plat_r-4-2, 0, -lug_drop-4])
                translate([-2,-4,0]) cube([4, 8, lug_drop+4+eps]);
            // antenna servo towers (open frames to save weight)
            for (s=[-1,1]) ant_servo_place(s) translate([0,0,-(tower_top - plat_t) + sv_tab_z])
                difference() {
                    translate([sv_body_mid - sv_tab_span/2 - 1.5, -sv_wid/2 - 2.4, 0])
                        cube([sv_tab_span+3, sv_wid+4.8, tower_top-plat_t]);
                    translate([-sv_shaft_x - sv_clear, -sv_wid/2 - sv_clear, -1])
                        cube([sv_len + 2*sv_clear, sv_wid + 2*sv_clear, tower_top]);
                    translate([sv_body_mid, 0, (tower_top-plat_t)/2 - 2]) cube([sv_tab_span-6, 40, tower_top-plat_t-12], center=true);
                    translate([sv_body_mid, 0, (tower_top-plat_t)/2 - 2]) cube([40, sv_wid-4, tower_top-plat_t-12], center=true);
                }
            // camera bracket behind Chotu's left eye
            translate([-eye_x - 15, cam_back_y - 3.5, plat_t]) difference() {
                cube([30, 2, eye_z + 14]);
                translate([15 - 7, -1, 2]) cube([14, 4, 8]);              // ribbon passes here
            }
            translate([-eye_x, cam_back_y - 1.5, plat_t + eye_z]) rotate([-90,0,0])
                for (x=[-1,1], y=[-1,1]) translate([x*cam_hole_dx/2, y*cam_hole_dy/2 + cam_lens_up, 0]) cylinder(d=4.5, h=1.5);
        }
        for (i=[0:5]) rotate(P_ang(i)) translate([plat_r-12, 0, -lug_drop]) rotate([0,90,0]) cylinder(d=2.6, h=14, $fn=16);
        for (s=[-1,1]) ant_servo_place(s) servo_screw_holes();
        translate([0, 6, -1]) rrect(22, 8, 2, plat_t+2);
        for (p=head_boss) translate([p[0], p[1], -1]) {
            cylinder(d=3.4, h=plat_t+2, $fn=16);
            cylinder(d1=6.5, d2=3.4, h=1.6, $fn=16);
        }
        // camera pilot holes (M2)
        translate([-eye_x, cam_back_y + 1, plat_t + eye_z]) rotate([90,0,0])
            for (x=[-1,1], y=[-1,1]) translate([x*cam_hole_dx/2, -(y*cam_hole_dy/2 + cam_lens_up), 0]) cylinder(d=1.8, h=8, $fn=12);
        // weight-saving holes
        translate([0, -24, -1]) cylinder(d=16, h=plat_t+2);
        translate([16, 27, -1]) cylinder(d=12, h=plat_t+2);
    }
}

module v2_head_shell() {
    yf = head_d/2;                       // front surface
    translate([0,0,plat_t]) difference() {
        union() {
            difference() {
                head_body(head_w, head_d, head_h, head_r);
                translate([0,0,-eps]) head_body(head_w-2*wall, head_d-2*wall, head_h-wall, head_r-wall);
            }
            for (p=head_boss) translate([p[0], p[1], 0]) cylinder(d=7, h=10);
            // 2 small tabs the visor rests on (glue it in)
            for (p=[[0, eye_z-vis_h/2+3], [0, eye_z+vis_h/2-3]])
                translate([p[0], yf - wall - 2.2, p[1]]) cube([8, 2.4, 8], center=true);
            // mic frame under the top
            translate([0, -10, head_h-wall-2]) difference() {
                cube([mic_board+3, mic_board+3, 4], center=true);
                cube([mic_board+0.4, mic_board+0.4, 5], center=true);
            }
        }
        // goggle opening
        translate([0, yf - wall - 1, eye_z]) pill(vis_w, vis_h, wall + 3);
        translate([0, -10, head_h-wall-1]) cylinder(d=3, h=10, $fn=16);       // mic hole
        for (s=[-1,1]) translate([s*ant_x, ant_y, head_h-8]) cylinder(d=13.5, h=12); // antenna holes
        for (p=head_boss) translate([p[0], p[1], -1]) cylinder(d=2.5, h=9, $fn=16);
        for (z=[12:6:36]) translate([0, -head_d/2, z]) cube([34, 6, 2.4], center=true);   // back vents
    }
}

// goggle visor (print in black). Head coordinates.
module v2_visor() {
    yf = head_d/2;
    translate([0, yf - wall - 0.4, plat_t + eye_z]) difference() {
        union() {
            pill(vis_w - 0.6, vis_h - 0.6, vis_t);
            // eye cups behind the visor (make both eyes look deep)
            for (s=[-1,1]) translate([s*eye_x, 0, 0]) rotate([90,0,0]) cylinder(d=eye_d+3, h=7);
            // raised eye rings on the front
            for (s=[-1,1]) translate([s*eye_x, vis_t, 0]) rotate([-90,0,0]) cylinder(d1=eye_d+5, d2=eye_d+2, h=1.2);
        }
        for (s=[-1,1]) translate([s*eye_x, -8, 0]) rotate([-90,0,0]) cylinder(d=eye_d, h=vis_t+20);
        // the right eye keeps a back wall (dummy lens), the left one has the camera hole
        translate([eye_x, -6.2, 0]) rotate([-90,0,0]) cylinder(d=eye_d+4, h=0.01);
    }
    // back disc of the right (dummy) eye
    translate([eye_x, yf - wall - 0.4 - 7, plat_t + eye_z]) rotate([-90,0,0]) cylinder(d=eye_d+3, h=1.2);
    // back ring of the left eye with the lens hole
    translate([-eye_x, yf - wall - 0.4 - 7, plat_t + eye_z]) rotate([-90,0,0]) difference() {
        cylinder(d=eye_d+3, h=1.2); translate([0,0,-1]) cylinder(d=cam_window_d+1, h=4);
    }
}

// FLEXIBLE antenna, option A: print the whole thing in TPU (rubbery
// filament). The thin stalk bends and springs back.
// FLEXIBLE antenna, option B (stiffer, very springy): print v2_antenna_hub
// in PLA, push a 2 mm spring-steel / piano wire (or a small spring)
// into its socket, and glue v2_antenna_tip on the end.
wire_d = 2.0;
module v2_antenna_hub() {
    difference() {
        union() {
            cylinder(d=11, h=5);
            translate([0,0,4]) cylinder(d1=8, d2=5, h=14);
        }
        translate([0,0,-eps]) cylinder(d=7.4, h=4);
        translate([0,-3.1,-eps]) cube([16, 6.2, 2.2]);
        translate([0,0,-eps]) cylinder(d=2.6, h=4.6, $fn=12);
        translate([0,0,5]) cylinder(d=wire_d+0.2, h=20, $fn=16);   // wire socket, 13 mm deep
    }
}
module v2_antenna_tip() {
    difference() { sphere(d=7, $fn=24); translate([0,0,-5]) cylinder(d=wire_d+0.2, h=5, $fn=16); }
}

// =====================================================================
//  FLEXIBLE PLA ANTENNA (v2.1)  - the SHAPE makes it bend, no TPU needed.
//  Two prints:
//   * v2_antenna_flex : flat antenna, printed LYING FLAT (strong layers).
//       a zigzag spring near the bottom + a slim curved stalk + round tip.
//   * v2_antenna_flex_hub : sits on the servo horn; the antenna's tang
//       slides into its slot (glue, or a M2 screw through the side).
//  Flat-printed thin PLA bends a lot and springs back; the zigzag adds
//  extra wobble right at the base, like a spring.
// =====================================================================
ant_t      = 2.4;   // antenna thickness (print height)
ant_beam   = 1.4;   // zigzag beam width (3 lines of a 0.4 nozzle)
tang_w     = 6;  tang_l = 12;
module _seg(a, b, d) hull() { translate(a) circle(d=d, $fn=16); translate(b) circle(d=d, $fn=16); }
module v2_antenna_flex() {     // print orientation: flat on the bed, z = thickness
    zig = [[0,tang_l], [-5,tang_l+3], [5,tang_l+6.5], [-5,tang_l+10], [5,tang_l+13.5], [-5,tang_l+17], [0,tang_l+20]];
    y0 = tang_l + 20; L = 52;
    linear_extrude(ant_t) union() {
        translate([-tang_w/2, 0]) square([tang_w, tang_l + 0.5]);                 // tang
        for (k=[0:len(zig)-2]) _seg(zig[k], zig[k+1], ant_beam);                  // zigzag spring
        for (k=[0:11]) let(t0=k/12, t1=(k+1)/12)                                  // slim curved stalk
            _seg([12*t0*t0, y0 + L*t0], [12*t1*t1, y0 + L*t1], 3 - 1.2*t0);
        translate([12, y0 + L + 2]) circle(d=7, $fn=32);                          // round tip
    }
}
module v2_antenna_flex_hub() {
    difference() {
        union() { cylinder(d=11, h=5); translate([0,0,4]) cylinder(d1=10, d2=8, h=13); }
        translate([0,0,-eps]) cylinder(d=7.4, h=4);
        translate([0,-3.1,-eps]) cube([16, 6.2, 2.2]);
        translate([0,0,-eps]) cylinder(d=2.6, h=4.6, $fn=12);
        translate([-(tang_w+0.4)/2, -(ant_t+0.3)/2, 5]) cube([tang_w+0.4, ant_t+0.3, 20]);   // slot for the tang
        translate([0, 0, 9]) rotate([90,0,0]) cylinder(d=1.8, h=12, center=true, $fn=12);   // optional M2 pin
    }
}
// standing up, as fitted (for the assembly view): antenna plane = YZ, leaning forward (+y)
module v2_antenna_fitted() {
    v2_antenna_flex_hub();
    translate([0,0,5]) rotate([90,0,90]) translate([0,0,-ant_t/2]) v2_antenna_flex();
}

module v2_antenna() {
    difference() {
        union() {
            cylinder(d=11, h=5);
            translate([0,0,4]) for (k=[0:13]) hull() {
                t0 = k/14; t1 = (k+1)/14;
                translate([0, 14*t0*t0, 66*t0]) sphere(d=5 - 2*t0, $fn=16);
                translate([0, 14*t1*t1, 66*t1]) sphere(d=5 - 2*t1, $fn=16);
            }
            translate([0, 14, 70]) sphere(d=6, $fn=24);
        }
        translate([0,0,-eps]) cylinder(d=7.4, h=4);
        translate([0,-3.1,-eps]) cube([16, 6.2, 2.2]);
        translate([0,0,-eps]) cylinder(d=2.6, h=10, $fn=12);
    }
}

// =====================================================================
//  ASSEMBLY v2
// =====================================================================
module chotu_v2(explode=0) {
    color("Gainsboro") translate([0,0,-explode*0.8]) base_plate();
    color("WhiteSmoke") base_shell();
    translate([0,0,-explode*0.8]) {
        color("Green") translate([pi_pos[0], pi_pos[1], plate_t+pi_standoff_h]) cube([pi_l, pi_w, 1.6]);
        color("Silver") translate([pi_pos[0]+pi_l-21, pi_pos[1]+2, plate_t+pi_standoff_h+1.6]) cube([21, 53, 16]);
        color("White") translate([bb_pos[0]-bb_l/2, bb_pos[1]-bb_w/2, plate_t+1.2]) cube([bb_l, bb_w, 8.5]);
        color("Black") translate([spk_pos[0]-spk_l/2, spk_pos[1]-spk_w/2, plate_t]) cube([spk_l, spk_w, spk_h]);
    }
    translate([0,0,Z_DECK - deck_t - sv_tab_z - sv_tab_t]) servo_dummy();
    color("DimGray") translate([0,0,Z_DECK+explode*0.3]) difference() {
        translate([-ls_size/2, -ls_size/2, 0]) cube([ls_size, ls_size, ls_h]);
        translate([0,0,-1]) cylinder(d=60, h=ls_h+2);
    }
    translate([0,0,Z_TORSO + explode*0.6]) {
        color("LightGray") v2_torso();
        for (i=[0:5]) torso_servo_place(i) servo_dummy();
        color("DarkBlue") translate([pca_pos[0]-pca_l/2, pca_pos[1]-pca_w/2, floor_t+3]) cube([pca_l, pca_w, 1.6]);
        if (explode == 0) color("White", 0.35) v2_body_shell();
        else translate([0,0,explode*1.6]) color("White") v2_body_shell();
    }
    for (i=[0:5]) color("Silver") rod(B(i) + [0,0,explode*0.6], P(i) + [0,0,explode*3.0]);
    translate([0,0,Z_PLAT + explode*3.0]) {
        color("LightGray") v2_head_platform();
        for (s=[-1,1]) ant_servo_place(s) servo_dummy();
        color("ForestGreen") translate([-eye_x, head_d/2 - wall - 4 - cam_lens_h, plat_t + eye_z]) rotate([90,0,0])
            translate([-cam_w/2, -cam_h/2 + cam_lens_up, -1.6]) cube([cam_w, cam_h, 1.6]);
        color("White") translate([0,0,explode*0.6]) v2_head_shell();
        color("DimGray") translate([0, explode*0.8, explode*0.6]) v2_visor();
        for (s=[-1,1]) color("DimGray") translate([s*ant_x, ant_y, plat_t + head_h + 2 + explode*0.9]) rotate(s*25) v2_antenna_fitted();
    }
}

if (part == "v2_assembly")          chotu_v2(0);
else if (part == "v2_exploded")     chotu_v2(40);
else if (part == "v2_base_shell")   translate([0,0,base_h]) rotate([180,0,0]) base_shell();
else if (part == "v2_torso")        v2_torso();
else if (part == "v2_body_shell")   v2_body_shell();
else if (part == "v2_head_platform") translate([0,0,lug_drop+4]) v2_head_platform();
else if (part == "v2_head_shell")   translate([0,0,plat_t+head_h]) rotate([180,0,0]) v2_head_shell();
else if (part == "v2_visor")        rotate([90,0,0]) translate([0, -(head_d/2 - wall - 0.4 + vis_t), -(plat_t+eye_z)]) v2_visor();
else if (part == "v2_antenna")      v2_antenna();
else if (part == "v2_antenna_hub")  v2_antenna_hub();
else if (part == "v2_antenna_tip")  v2_antenna_tip();
else if (part == "v2_antenna_flex") v2_antenna_flex();
else if (part == "v2_antenna_flex_hub") v2_antenna_flex_hub();
else if (part == "v2_antenna_fitted") v2_antenna_fitted();
