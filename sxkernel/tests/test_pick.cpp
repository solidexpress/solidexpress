#include <catch.hpp>

#include "sx/document.hpp"
#include "sx/pick.hpp"
#include "sx/shape_utils.hpp"

using namespace sx;

TEST_CASE("ray pick hits the nearest face of a box", "[pick]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_box(10, 10, 10), "B");

    // Ray from above, straight down at the center: must hit the top face (z=10).
    auto hit = pick_ray(doc, {5, 5, 100}, {0, 0, -1});
    REQUIRE(hit.has_value());
    REQUIRE(hit->body == body_id);
    REQUIRE(hit->point[2] == Approx(10.0).margin(1e-6));
    REQUIRE(hit->distance == Approx(90.0).margin(1e-6));

    auto desc = shape::describe_face(doc.resolve(hit->face));
    REQUIRE(desc.find("planar") != std::string::npos);
    REQUIRE(desc.find("normal (0, 0, 1)") != std::string::npos);
}

TEST_CASE("ray pick misses when pointed away", "[pick]") {
    Document doc;
    doc.add_body(shape::make_box(10, 10, 10), "B");
    auto hit = pick_ray(doc, {5, 5, 100}, {0, 0, 1});  // pointing up, away from box
    REQUIRE(!hit.has_value());
}

TEST_CASE("ray pick chooses nearest of two bodies", "[pick]") {
    Document doc;
    shape::Placement far_p;
    far_p.origin = {0, 0, -50};
    doc.add_body(shape::make_box(10, 10, 10, far_p), "Far");
    auto near_id = doc.add_body(shape::make_box(10, 10, 10), "Near");

    auto hit = pick_ray(doc, {5, 5, 100}, {0, 0, -1});
    REQUIRE(hit.has_value());
    REQUIRE(hit->body == near_id);
}

TEST_CASE("ray pick hits cylinder lateral face", "[pick]") {
    Document doc;
    auto body_id = doc.add_body(shape::make_cylinder(5, 20), "C");
    // Horizontal ray at half height, aimed at the axis.
    auto hit = pick_ray(doc, {100, 0, 10}, {-1, 0, 0});
    REQUIRE(hit.has_value());
    REQUIRE(hit->body == body_id);
    auto desc = shape::describe_face(doc.resolve(hit->face));
    REQUIRE(desc.find("cylindrical") != std::string::npos);
    REQUIRE(hit->point[0] == Approx(5.0).margin(1e-6));
}

TEST_CASE("pick_ray_body ignores a closer other body", "[pick]") {
    Document doc;
    shape::Placement far_p;
    far_p.origin = {0, 0, -50};
    auto far_id = doc.add_body(shape::make_box(10, 10, 10, far_p), "Far");
    doc.add_body(shape::make_box(10, 10, 10), "Near");

    auto all = pick_ray(doc, {5, 5, 100}, {0, 0, -1});
    REQUIRE(all.has_value());
    REQUIRE(all->body != far_id);

    auto only_far = pick_ray_body(doc, far_id, {5, 5, 100}, {0, 0, -1});
    REQUIRE(only_far.has_value());
    REQUIRE(only_far->body == far_id);
    REQUIRE(only_far->point[2] == Approx(-40.0).margin(1e-6));
}
