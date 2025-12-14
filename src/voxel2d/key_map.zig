const sdl = @cImport(@cInclude("SDL3/SDL.h"));

pub const Type = @TypeOf(sdl.SDL_SCANCODE_A);

pub const A = sdl.SDL_SCANCODE_A;
pub const B = sdl.SDL_SCANCODE_B;
pub const C = sdl.SDL_SCANCODE_C;
pub const D = sdl.SDL_SCANCODE_D;
pub const E = sdl.SDL_SCANCODE_E;
pub const F = sdl.SDL_SCANCODE_F;
pub const G = sdl.SDL_SCANCODE_G;
pub const H = sdl.SDL_SCANCODE_H;
pub const I = sdl.SDL_SCANCODE_I;
pub const J = sdl.SDL_SCANCODE_J;
pub const K = sdl.SDL_SCANCODE_K;
pub const L = sdl.SDL_SCANCODE_L;
pub const M = sdl.SDL_SCANCODE_M;
pub const N = sdl.SDL_SCANCODE_N;
pub const O = sdl.SDL_SCANCODE_O;
pub const P = sdl.SDL_SCANCODE_P;
pub const Q = sdl.SDL_SCANCODE_Q;
pub const R = sdl.SDL_SCANCODE_R;
pub const S = sdl.SDL_SCANCODE_S;
pub const T = sdl.SDL_SCANCODE_T;
pub const U = sdl.SDL_SCANCODE_U;
pub const V = sdl.SDL_SCANCODE_V;
pub const W = sdl.SDL_SCANCODE_W;
pub const X = sdl.SDL_SCANCODE_X;
pub const Y = sdl.SDL_SCANCODE_Y;
pub const Z = sdl.SDL_SCANCODE_Z;

pub const Num1 = sdl.SDL_SCANCODE_1;
pub const Num2 = sdl.SDL_SCANCODE_2;
pub const Num3 = sdl.SDL_SCANCODE_3;
pub const Num4 = sdl.SDL_SCANCODE_4;
pub const Num5 = sdl.SDL_SCANCODE_5;
pub const Num6 = sdl.SDL_SCANCODE_6;
pub const Num7 = sdl.SDL_SCANCODE_7;
pub const Num8 = sdl.SDL_SCANCODE_8;
pub const Num9 = sdl.SDL_SCANCODE_9;
pub const Num0 = sdl.SDL_SCANCODE_0;

pub const Return = sdl.SDL_SCANCODE_RETURN;
pub const Escape = sdl.SDL_SCANCODE_ESCAPE;
pub const Backspace = sdl.SDL_SCANCODE_BACKSPACE;
pub const Tab = sdl.SDL_SCANCODE_TAB;
pub const Space = sdl.SDL_SCANCODE_SPACE;

// Punctuation
pub const Minus = sdl.SDL_SCANCODE_MINUS;
pub const Equals = sdl.SDL_SCANCODE_EQUALS;
pub const LeftBracket = sdl.SDL_SCANCODE_LEFTBRACKET;
pub const RightBracket = sdl.SDL_SCANCODE_RIGHTBRACKET;
pub const Backslash = sdl.SDL_SCANCODE_BACKSLASH;
pub const Semicolon = sdl.SDL_SCANCODE_SEMICOLON;
pub const Apostrophe = sdl.SDL_SCANCODE_APOSTROPHE;
pub const Grave = sdl.SDL_SCANCODE_GRAVE;
pub const Comma = sdl.SDL_SCANCODE_COMMA;
pub const Period = sdl.SDL_SCANCODE_PERIOD;
pub const Slash = sdl.SDL_SCANCODE_SLASH;

// Function keys
pub const F1 = sdl.SDL_SCANCODE_F1;
pub const F2 = sdl.SDL_SCANCODE_F2;
pub const F3 = sdl.SDL_SCANCODE_F3;
pub const F4 = sdl.SDL_SCANCODE_F4;
pub const F5 = sdl.SDL_SCANCODE_F5;
pub const F6 = sdl.SDL_SCANCODE_F6;
pub const F7 = sdl.SDL_SCANCODE_F7;
pub const F8 = sdl.SDL_SCANCODE_F8;
pub const F9 = sdl.SDL_SCANCODE_F9;
pub const F10 = sdl.SDL_SCANCODE_F10;
pub const F11 = sdl.SDL_SCANCODE_F11;
pub const F12 = sdl.SDL_SCANCODE_F12;

// Navigation
pub const Insert = sdl.SDL_SCANCODE_INSERT;
pub const Home = sdl.SDL_SCANCODE_HOME;
pub const PageUp = sdl.SDL_SCANCODE_PAGEUP;
pub const Delete = sdl.SDL_SCANCODE_DELETE;
pub const End = sdl.SDL_SCANCODE_END;
pub const PageDown = sdl.SDL_SCANCODE_PAGEDOWN;
pub const Right = sdl.SDL_SCANCODE_RIGHT;
pub const Left = sdl.SDL_SCANCODE_LEFT;
pub const Down = sdl.SDL_SCANCODE_DOWN;
pub const Up = sdl.SDL_SCANCODE_UP;

// Modifiers
pub const LCtrl = sdl.SDL_SCANCODE_LCTRL;
pub const LShift = sdl.SDL_SCANCODE_LSHIFT;
pub const LAlt = sdl.SDL_SCANCODE_LALT;
pub const LMeta = sdl.SDL_SCANCODE_LGUI;

pub const RCtrl = sdl.SDL_SCANCODE_RCTRL;
pub const RShift = sdl.SDL_SCANCODE_RSHIFT;
pub const RAlt = sdl.SDL_SCANCODE_RALT;
pub const RMeta = sdl.SDL_SCANCODE_RGUI;

//-----------------------------------------------------------
// Numeric keypad (keypad keys)
//-----------------------------------------------------------
pub const KP_NumLock = sdl.SDL_SCANCODE_NUMLOCKCLEAR;

pub const KP_Divide = sdl.SDL_SCANCODE_KP_DIVIDE;
pub const KP_Multiply = sdl.SDL_SCANCODE_KP_MULTIPLY;
pub const KP_Minus = sdl.SDL_SCANCODE_KP_MINUS;
pub const KP_Plus = sdl.SDL_SCANCODE_KP_PLUS;
pub const KP_Enter = sdl.SDL_SCANCODE_KP_ENTER;

pub const KP_1 = sdl.SDL_SCANCODE_KP_1;
pub const KP_2 = sdl.SDL_SCANCODE_KP_2;
pub const KP_3 = sdl.SDL_SCANCODE_KP_3;
pub const KP_4 = sdl.SDL_SCANCODE_KP_4;
pub const KP_5 = sdl.SDL_SCANCODE_KP_5;
pub const KP_6 = sdl.SDL_SCANCODE_KP_6;
pub const KP_7 = sdl.SDL_SCANCODE_KP_7;
pub const KP_8 = sdl.SDL_SCANCODE_KP_8;
pub const KP_9 = sdl.SDL_SCANCODE_KP_9;
pub const KP_0 = sdl.SDL_SCANCODE_KP_0;

pub const KP_Period = sdl.SDL_SCANCODE_KP_PERIOD;
