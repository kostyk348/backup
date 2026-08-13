program MyWM;

{$mode objfpc}{$H+}

uses
  x, xlib, BaseUnix, Unix, ctypes;

// Коды клавиш
const
  XK_F1 = $FFBE;
  XK_F4 = $FFC1;

var
  Dis: PDisplay;
  Root: TWindow;
  Attr: TXWindowAttributes;
  Start: TXButtonEvent;
  Ev: TXEvent;

// Функция запуска команд
procedure RunCmd(const Cmd: string);
begin
  if FpFork = 0 then
  begin
    fpSystem(PChar(Cmd));
    Halt(0);
  end;
end;

begin
  // 1. Подключение
  Dis := XOpenDisplay(nil);
  if Dis = nil then
  begin
    WriteLn('Error: Cannot open display!');
    Halt(1);
  end;

  Root := XDefaultRootWindow(Dis);

  // 2. Биндим клавиши (1 вместо True, так как нужен int)

  // Alt + F1
  XGrabKey(Dis, XKeysymToKeycode(Dis, XK_F1), Mod1Mask, Root, 1, GrabModeAsync, GrabModeAsync);

  // Alt + F4
  XGrabKey(Dis, XKeysymToKeycode(Dis, XK_F4), Mod1Mask, Root, 1, GrabModeAsync, GrabModeAsync);

  // Alt + ЛКМ
  XGrabButton(Dis, 1, Mod1Mask, Root, 1, ButtonPressMask, GrabModeAsync, GrabModeAsync, None, None);
  // Alt + ПКМ
  XGrabButton(Dis, 3, Mod1Mask, Root, 1, ButtonPressMask, GrabModeAsync, GrabModeAsync, None, None);

  WriteLn('MyWM started! Press Alt+F1 to run xterm. Press Alt+F4 to close.');

  // 3. Цикл
  while True do
  begin
    XNextEvent(Dis, @Ev);

    // ИСПРАВЛЕНО ТУТ: используем type_ (с подчеркиванием)
    case LongInt(Ev.type) of
      KeyPress:
      begin
        if (Ev.xkey.keycode = XKeysymToKeycode(Dis, XK_F1)) then
          RunCmd('xterm &');

        if (Ev.xkey.keycode = XKeysymToKeycode(Dis, XK_F4)) then
        begin
           if Ev.xkey.subwindow <> None then
             XKillClient(Dis, Ev.xkey.subwindow);
        end;
      end;

      ButtonPress:
      begin
        if Ev.xbutton.subwindow <> None then
        begin
          XRaiseWindow(Dis, Ev.xbutton.subwindow);
          XGetWindowAttributes(Dis, Ev.xbutton.subwindow, @Attr);
          Start := Ev.xbutton;
        end;
      end;

      MotionNotify:
      begin
        if Start.subwindow <> None then
        begin
          // Таскаем окно
          XMoveWindow(Dis, Start.subwindow,
            Attr.x + (Ev.xbutton.x_root - Start.x_root),
            Attr.y + (Ev.xbutton.y_root - Start.y_root));
        end;
      end;

      ButtonRelease:
      begin
        Start.subwindow := None;
      end;
    end;
  end;
end.
