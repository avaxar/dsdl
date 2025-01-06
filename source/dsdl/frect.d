/++
 + Authors: R. Ethan Halim <me@avaxar.dev>
 + Copyright: Copyright © 2023-2025, R. Ethan Halim
 + License: $(LINK2 https://mit-license.org, MIT License)
 +/

module dsdl.frect;
@safe:

// dfmt off
import bindbc.sdl;
static if (sdlSupport >= SDLSupport.v2_0_10):
// dfmt on

import dsdl.sdl;
import dsdl.rect;

import std.format : format;
import std.typecons : Nullable, nullable;

/++
 + D struct that wraps `SDL_FPoint` (from SDL 2.0.10) containing 2D floating point coordinate pair
 +
 + `dsdl.FPoint` stores `float`ing point `x` and `y` coordinate points. This wrapper also implements
 + vector-like operator overloading.
 +/
struct FPoint {
    SDL_FPoint sdlFPoint; /// Internal `SDL_FPoint` struct

    this() @disable;

    /++
     + Constructs a `dsdl.FPoint` from a vanilla `SDL_FPoint` from bindbc-sdl
     +
     + Params:
     +   sdlFPoint = the `dsdl.FPoint` struct
     +/
    this(SDL_FPoint sdlFPoint) {
        this.sdlFPoint = sdlFPoint;
    }

    /++
     + Constructs a `dsdl.FPoint` by feeding in an `x` and `y` pair
     +
     + Params:
     +   x = x coordinate point
     +   y = y coordinate point
     +/
    this(float x, float y) {
        this.x = x;
        this.y = y;
    }

    /++
     + Constructs a `dsdl.FPoint` by feeding in an array of `x` and `y`
     +
     + Params:
     +   xy = x and y coordinate point array
     +/
    this(float[2] xy) {
        this.sdlFPoint.x = xy[0];
        this.sdlFPoint.y = xy[1];
    }

    /++
     + Constructs a `dsdl.FPoint` from a `dsdl.Point`
     +
     + Params:
     +   point = `dsdl.Point` whose attributes are to be copied
     +/
    this(Point point) {
        this.sdlFPoint.x = point.x;
        this.sdlFPoint.y = point.y;
    }

    /++
     + Unary element-wise operation overload template
     +/
    FPoint opUnary(string op)() const {
        return FPoint(mixin(op ~ "this.x"), mixin(op ~ "this.y"));
    }

    /++
     + Binary element-wise operation overload template
     +/
    FPoint opBinary(string op)(const FPoint other) const {
        return FPoint(mixin("this.x" ~ op ~ "other.x"), mixin("this.y" ~ op ~ "other.y"));
    }

    /++
     + Binary operation overload template with scalars
     +/
    FPoint opBinary(string op)(float scalar) const if (op == "*" || op == "/") {
        return FPoint(mixin("this.x" ~ op ~ "scalar"), mixin("this.y" ~ op ~ "scalar"));
    }

    /++
     + Element-wise operator assignment overload
     +/
    ref inout(FPoint) opOpAssign(string op)(const FPoint other) return inout {
        mixin("this.x" ~ op ~ "=other.x");
        mixin("this.y" ~ op ~ "=other.y");
        return this;
    }

    /++
     + Operator assignment overload with scalars
     +/
    ref inout(FPoint) opOpAssign(string op)(const float scalar) return inout if (op == "*" || op == "/") {
        mixin("this.x" ~ op ~ "=scalar");
        mixin("this.y" ~ op ~ "=scalar");
        return this;
    }

    /++
     + Formats the `dsdl.FPoint` into its construction representation: `"dsdl.FPoint(<x>, <y>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.FPoint(%f, %f)".format(this.x, this.y);
    }

    /++
     + Proxy to the X value of the `dsdl.FPoint`
     +
     + Returns: X value of the `dsdl.FPoint`
     +/
    ref inout(float) x() return inout @property {
        return this.sdlFPoint.x;
    }

    /++
     + Proxy to the Y value of the `dsdl.FPoint`
     +
     + Returns: Y value of the `dsdl.FPoint`
     +/
    ref inout(float) y() return inout @property {
        return this.sdlFPoint.y;
    }

    /++
     + Static array proxy of the `dsdl.FPoint`
     +
     + Returns: array of `x` and `y`
     +/
    ref inout(float[2]) array() return inout @property @trusted {
        return *cast(inout(float[2]*))&this.sdlFPoint;
    }
}
///
unittest {
    auto a = dsdl.FPoint(1.0, 2.0);
    auto b = a + a;
    assert(b == dsdl.FPoint(2.0, 4.0));

    auto c = a * 2.0;
    assert(b == c);
}

/++
 + D struct that wraps `SDL_FRect` (from SDL 2.0.10) representing a rectangle of floating point 2D
 + coordinate and dimension
 +
 + `dsdl.FRect` stores `float`ing point `x` and `y` coordinate points, as well as `w`idth and `h`eight which
 + specifies the rectangle's dimension. `x` and `y` symbolize the top-left coordinate of the rectangle, and
 + the `w`idth and `h`eight extend to the positive plane of both axes.
 +/
struct FRect {
    SDL_FRect sdlFRect; /// Internal `SDL_FRect` struct

    this() @disable;

    /++
     + Constructs a `dsdl.FRect` from a vanilla `SDL_FRect` from bindbc-sdl
     +
     + Params:
     +   sdlFRect = the `SDL_FRect` struct
     +/
    this(SDL_FRect sdlFRect) {
        this.sdlFRect = sdlFRect;
    }

    /++
     + Constructs a `dsdl.FRect` by feeding in the `x`, `y`, `width`, and `height` of the rectangle
     +
     + Params:
     +   x = top-left x coordinate point of the rectangle
     +   y = top-left y coordinate point of the rectangle
     +   width = rectangle width
     +   height = rectangle height
     +/
    this(float x, float y, float width, float height) {
        this.sdlFRect.x = x;
        this.sdlFRect.y = y;
        this.sdlFRect.w = width;
        this.sdlFRect.h = height;
    }

    /++
     + Constructs a `dsdl.FRect` by feeding in a `dsdl.FPoint` as the `xy`, then `width` and `height` of
     + the rectangle
     +
     + Params:
     +   point = top-left point of the rectangle
     +   width = rectangle width
     +   height = rectangle height
     +/
    this(FPoint point, float width, float height) {
        this.sdlFRect.x = point.x;
        this.sdlFRect.y = point.y;
        this.sdlFRect.w = width;
        this.sdlFRect.h = height;
    }

    /++
     + Constructs a `dsdl.FRect` from a `dsdl.Rect`
     +
     + Params:
     +   rect = `dsdl.Rect` whose attributes are to be copied
     +/
    this(Rect rect) {
        this.sdlFRect.x = rect.x;
        this.sdlFRect.y = rect.y;
        this.sdlFRect.w = rect.width;
        this.sdlFRect.h = rect.height;
    }

    /++
     + Binary operation overload template to move rectangle's position by an `offset` as a `dsdl.FPoint`
     +/
    FRect opBinary(string op)(const FPoint offset) const if (op == "+" || op == "-") {
        return FRect(Foint(mixin("this.x" ~ op ~ "offset.x"), mixin("this.y" ~ op ~ "offset.y")),
                this.width, this.height);
    }

    /++
     + Operator assignment overload template to move rectangle's position in-place by an `offset` as a
     + `dsdl.FPoint`
     +/
    ref inout(FPoint) opOpAssign(string op)(const FPoint offset) return inout if (op == "+" || op == "-") {
        mixin("this.x" ~ op ~ "=offset.x");
        mixin("this.y" ~ op ~ "=offset.y");
        return this;
    }

    /++
     + Formats the `dsdl.FRect` into its construction representation: `"dsdl.FRect(<x>, <y>, <w>, <h>)"`
     +
     + Returns: the formatted `string`
     +/
    string toString() const {
        return "dsdl.FRect(%f, %f, %f, %f)".format(this.x, this.y, this.width, this.height);
    }

    /++
     + Proxy to the X value of the `dsdl.FRect`
     +
     + Returns: X value of the `dsdl.FRect`
     +/
    ref inout(float) x() return inout @property {
        return this.sdlFRect.x;
    }

    /++
     + Proxy to the Y value of the `dsdl.FRect`
     +
     + Returns: Y value of the `dsdl.FRect`
     +/
    ref inout(float) y() return inout @property {
        return this.sdlFRect.y;
    }

    /++
     + Proxy to the `dsdl.FPoint` containing the `x` and `y` value of the `dsdl.FRect`
     +
     + Returns: reference to the `dsdl.FPoint` structure
     +/
    ref inout(FPoint) point() return inout @property @trusted {
        return *cast(inout(FPoint*))&this.sdlFRect.x;
    }

    /++
     + Proxy to the width of the `dsdl.FRect`
     +
     + Returns: width of the `dsdl.FRect`
     +/
    ref inout(float) width() return inout @property {
        return this.sdlFRect.w;
    }

    /++
     + Proxy to the height of the `dsdl.FRect`
     +
     + Returns: height of the `dsdl.FRect`
     +/
    ref inout(float) height() return inout @property {
        return this.sdlFRect.h;
    }

    /++
     + Proxy to the size array containing the `width` and `height` of the `dsdl.FRect`
     +
     + Returns: reference to the static `float[2]` array
     +/
    ref inout(float[2]) size() return inout @property @trusted {
        return *cast(inout(float[2]*))&this.sdlFRect.w;
    }

    static if (sdlSupport >= SDLSupport.v2_0_22) {
        /++
         + Wraps `SDL_FRectEmpty` (from SDL 2.0.22) which checks if the `dsdl.FRect` is an empty rectangle
         +
         + Returns: `true` if it is empty, otherwise `false`
         +/
        bool empty() const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            return SDL_FRectEmpty(&this.sdlFRect);
        }

        /++
         + Wraps `SDL_PointInFRect` (from SDL 2.0.22) which sees whether the coordinate of a `dsdl.FPoint`
         + is inside the `dsdl.FRect`
         +
         + Params:
         +   point = the `dsdl.FPoint` to check its collision of with the `dsdl.FRect` instance
         + Returns: `true` if it is within, otherwise `false`
         +/
        bool pointInRect(FPoint point) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            return SDL_PointInFRect(&point.sdlFPoint, &this.sdlFRect);
        }

        /++
         + Wraps `SDL_HasIntersectionF` (from SDL 2.0.22) which sees whether two `dsdl.FRect`s intersect
         + each other
         +
         + Params:
         +   rect = other `dsdl.FRect` to check its intersection of with the `dsdl.FRect`
         + Returns: `true` if both have intersection with each other, otherwise `false`
         +/
        bool hasIntersection(FRect rect) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            return SDL_HasIntersectionF(&this.sdlFRect, &rect.sdlFRect) == SDL_TRUE;
        }

        /++
         + Wraps `SDL_IntersectFRectAndLine` (from SDL 2.0.22) which sees whether a line intersects with the
         + `dsdl.FRect`
         +
         + Params:
         +   line = set of two `dsdl.FPoint`s denoting the start and end coordinates of the line to check its
         +          intersection of with the `dsdl.FRect`
         + Returns: `true` if it intersects, otherwise `false`
         +/
        bool hasLineIntersection(FPoint[2] line) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            return SDL_IntersectFRectAndLine(&this.sdlFRect, &line[0].sdlFPoint.x,
                    &line[0].sdlFPoint.y, &line[1].sdlFPoint.x, &line[1].sdlFPoint.y) == SDL_TRUE;
        }

        /++
         + Wraps `SDL_IntersectFRect` (from SDL 2.0.22) which attempts to get the rectangle of intersection
         + between two `dsdl.FRect`s
         +
         + Params:
         +   other = other `dsdl.FRect` with which the `dsdl.FRect` is intersected
         + Returns: non-null `Nullable!FRect` instance if intersection is present, otherwise a null one
         +/
        Nullable!FRect intersectRect(FRect other) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            FRect intersection = void;
            if (SDL_IntersectFRect(&this.sdlFRect, &other.sdlFRect, &intersection.sdlFRect) == SDL_TRUE) {
                return intersection.nullable;
            }
            else {
                return Nullable!FRect.init;
            }
        }

        /++
         + Wraps `SDL_IntersectFRectAndLine` (from SDL 2.0.22) which attempts to clip a line segment in the
         + boundaries of the `dsdl.FRect`
         +
         + Params:
         +   line = set of two `dsdl.FPoint`s denoting the start and end coordinates of the line to clip from its
         +          intersection with the `dsdl.FRect`
         + Returns: non-null `Nullable!(FPoint[2])` as the clipped line if there's an intersection, otherwise a null one
         +/
        Nullable!(FPoint[2]) intersectLine(FPoint[2] line) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            if (SDL_IntersectFRectAndLine(&this.sdlFRect, &line[0].sdlFPoint.x,
                    &line[0].sdlFPoint.y, &line[1].sdlFPoint.x, &line[1].sdlFPoint.y) == SDL_TRUE) {
                FPoint[2] intersection = [line[0], line[1]];
                return intersection.nullable;
            }
            else {
                return Nullable!(FPoint[2]).init;
            }
        }

        /++
         + Wraps `SDL_UnionFRect` which creates a `dsdl.FRect` (from SDL 2.0.22) of the minimum size to
         + enclose two given `dsdl.FRect`s
         +
         + Params:
         +   other = other `dsdl.FRect` to unify with the `dsdl.FRect`
         + Returns: `dsdl.FRect` of the minimum size to enclose the `dsdl.FRect` and `other`
         +/
        FRect unify(FRect other) const @trusted
        in {
            assert(getVersion() >= Version(2, 0, 22));
        }
        do {
            FRect union_ = void;
            SDL_UnionFRect(&this.sdlFRect, &other.sdlFRect, &union_.sdlFRect);
            return union_;
        }

        ///
        unittest {
            auto rect1 = dsdl.FRect(-2.0, -2.0, 3.0, 3.0);
            auto rect2 = dsdl.FRect(-1.0, -1.0, 3.0, 3.0);

            assert(rect1.hasIntersection(rect2));
            assert(rect1.intersectRect(rect2).get == dsdl.FRect(-1.0, -1.0, 2.0, 2.0));
        }
    }
}
