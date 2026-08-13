unit comtrolscreen;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  BGRABitmap, BGRABitmapTypes, BGRAVirtualScreen, Process;

type

  { TFrmControl }

  TFrmControl = class(TForm)
    LogList: TListBox;
    MainScreen: TBGRAVirtualScreen;
    VolScreen: TBGRAVirtualScreen;
    BriScreen: TBGRAVirtualScreen;
    ScrWifi: TBGRAVirtualScreen;
    ScrBlue: TBGRAVirtualScreen;

    procedure FormCreate(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure MainScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);

    procedure BriScreenMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BriScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);

    procedure VolScreenMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure VolScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);

    procedure ScrWifiRedraw(Sender: TObject; Bitmap: TBGRABitmap);
    procedure ScrWifiMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure ScrBlueRedraw(Sender: TObject; Bitmap: TBGRABitmap);
    procedure ScrBlueMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

  private
    FVol, FBri: Integer;
    FWifi, FBlue: Boolean;
    const
      CYBER_BLACK = $000D0D0D;
      CYBER_GREEN = $0000FF41;
      CYBER_DIM   = $00004411;
      CYBER_WHITE = $00E0E0E0;
    procedure AddLog(Msg: string);
    procedure RunCmd(Cmd: string);
    procedure RefreshButtons;
  public

  end;

var
  FrmControl: TFrmControl;

implementation

{$R *.lfm}

{ TFrmControl }

// --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

procedure TFrmControl.RunCmd(Cmd: string);
var P: TProcess;
begin
  P := TProcess.Create(nil);
  try
    P.Executable := '/bin/sh';
    P.Parameters.Add('-c');
    P.Parameters.Add(Cmd);
    P.Options := [poNoConsole];
    P.Execute;
  finally
    P.Free;
  end;
end;

procedure TFrmControl.AddLog(Msg: string);
begin
  LogList.Items.Insert(0, '> ' + FormatDateTime('hh:nn:ss', Now) + ' ' + Msg);
  if LogList.Items.Count > 10 then LogList.Items.Delete(10);
end;

// --- ИНИЦИАЛИЗАЦИЯ ---

procedure TFrmControl.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;
  Color := clBlack;
  AlphaBlend := True;
  AlphaBlendValue := 245;
  Width := 400;
  Height := 450;

  FVol := 50;
  FBri := 70;
  FWifi := True;
  FBlue := False;

  MainScreen := TBGRAVirtualScreen.Create(Self);
  MainScreen.Parent := Self;
  MainScreen.Align := alClient;
  MainScreen.OnRedraw := @MainScreenRedraw;

  LogList := TListBox.Create(Self);
  LogList.Parent := MainScreen;
  LogList.Color := CYBER_BLACK;
  LogList.BorderStyle := bsNone;
  LogList.Font.Name := 'JetBrainsMono NF';
  LogList.Font.Color := CYBER_GREEN;
  LogList.Font.Size := 9;
  LogList.SetBounds(20, 350, 360, 80);

  VolScreen := TBGRAVirtualScreen.Create(Self);
  VolScreen.Parent := MainScreen;
  VolScreen.SetBounds(20, 80, 360, 50);
  VolScreen.Cursor := crHandPoint;
  VolScreen.OnRedraw := @VolScreenRedraw;
  VolScreen.OnMouseDown := @VolScreenMouseDown;

  BriScreen := TBGRAVirtualScreen.Create(Self);
  BriScreen.Parent := MainScreen;
  BriScreen.SetBounds(20, 150, 360, 50);
  BriScreen.Cursor := crHandPoint;
  BriScreen.OnRedraw := @BriScreenRedraw;
  BriScreen.OnMouseDown := @BriScreenMouseDown;

  ScrWifi := TBGRAVirtualScreen.Create(Self);
  ScrWifi.Parent := MainScreen;
  ScrWifi.SetBounds(20, 230, 170, 100);
  ScrWifi.Cursor := crHandPoint;
  ScrWifi.OnRedraw := @ScrWifiRedraw;
  ScrWifi.OnMouseDown := @ScrWifiMouseDown;

  ScrBlue := TBGRAVirtualScreen.Create(Self);
  ScrBlue.Parent := MainScreen;
  ScrBlue.SetBounds(210, 230, 170, 100);
  ScrBlue.Cursor := crHandPoint;
  ScrBlue.OnRedraw := @ScrBlueRedraw;
  ScrBlue.OnMouseDown := @ScrBlueMouseDown;
end;

procedure TFrmControl.FormShow(Sender: TObject);
begin
  AddLog('SYSTEM_OVERRIDE_INIT // OK');
end;

procedure TFrmControl.FormDeactivate(Sender: TObject);
begin
  Hide;
end;

procedure TFrmControl.RefreshButtons;
begin
  ScrWifi.DiscardBitmap;
  ScrBlue.DiscardBitmap;
end;

// --- ОТРИСОВКА ---

procedure TFrmControl.MainScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);
var
  C: TBGRAPixel;
begin
  C := BGRA(0, 255, 65, 255);

  Bitmap.Fill(BGRA(10, 10, 12, 240));
  Bitmap.Rectangle(0, 0, Bitmap.Width, Bitmap.Height, C, 2);

  Bitmap.FillPolyAntialias([PointF(0,0), PointF(20,0), PointF(0,20)], C);

  Bitmap.FillPolyAntialias([
    PointF(Bitmap.Width, Bitmap.Height),
    PointF(Bitmap.Width-20, Bitmap.Height),
    PointF(Bitmap.Width, Bitmap.Height-20)
  ], C);

  Bitmap.FontName := 'JetBrainsMono NF';
  Bitmap.FontHeight := 20;
  Bitmap.FontAntialias := True;
  Bitmap.TextOut(30, 10, 'CONTROL_NODE // V.1.0', C, taLeftJustify);

  Bitmap.DrawLineAntialias(20, 40, Bitmap.Width-20, 40, C, 1);
end;

procedure DrawCyberBar(Bitmap: TBGRABitmap; Val: Integer; Icon, Title: string);
var
  i, BoxW, Gap, Count: Integer;
  ActiveC, PassiveC: TBGRAPixel;
begin
  ActiveC := BGRA(0, 255, 65, 255);
  PassiveC := BGRA(0, 60, 20, 255);

  Bitmap.FontName := 'JetBrainsMono NF';
  Bitmap.FontHeight := 16;
  Bitmap.TextOut(0, 10, Icon, ActiveC, taLeftJustify);

  Bitmap.FontHeight := 10;
  Bitmap.TextOut(0, 30, Title, ActiveC, taLeftJustify);

  Count := 20;
  Gap := 3;
  BoxW := (Bitmap.Width - 40 - (Count * Gap)) div Count;

  for i := 0 to Count - 1 do
  begin
    if (i / Count) * 100 < Val then
      Bitmap.Rectangle(40 + i*(BoxW+Gap), 5, 40 + i*(BoxW+Gap) + BoxW, 35, ActiveC, BGRA(0,255,0,50), dmSet)
    else
      Bitmap.Rectangle(40 + i*(BoxW+Gap), 5, 40 + i*(BoxW+Gap) + BoxW, 35, PassiveC, BGRA(0,0,0,0), dmSet);
  end;

  Bitmap.FontHeight := 16;
  Bitmap.TextOut(Bitmap.Width, 10, IntToStr(Val) + '%', ActiveC, taRightJustify);
end;

// ИСПРАВЛЕННАЯ ПРОЦЕДУРА ОТРИСОВКИ КНОПКИ
procedure DrawCyberButton(Bitmap: TBGRABitmap; Active: Boolean; Icon, Text1, Text2: string);
var
  BgC, BordC, TextC: TBGRAPixel;
begin
  if Active then
  begin
    BgC := BGRA(0, 40, 10, 255);
    BordC := BGRA(0, 255, 65, 255);
    TextC := BordC;
  end
  else
  begin
    BgC := BGRA(13, 13, 13, 255);
    BordC := BGRA(0, 68, 17, 255);
    TextC := BordC;
  end;

  // 1. Сначала заливаем фон (Fill)
  Bitmap.FillRoundRectAntialias(0, 0, Bitmap.Width, Bitmap.Height, 5, 5, BgC);

  // 2. Потом рисуем рамку (Draw) - толщина 2
  Bitmap.DrawRoundRectAntialias(0, 0, Bitmap.Width, Bitmap.Height, 5, 5, BordC, 2);

  Bitmap.FontName := 'JetBrainsMono NF';
  Bitmap.FontHeight := 24;
  Bitmap.FontAntialias := True;

  Bitmap.TextOut(Bitmap.Width div 2, 20, Icon, TextC, taCenter);

  Bitmap.FontHeight := 12;
  Bitmap.TextOut(Bitmap.Width div 2, 60, Text1, TextC, taCenter);
  Bitmap.TextOut(Bitmap.Width div 2, 75, Text2, TextC, taCenter);
end;

procedure TFrmControl.VolScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);
begin
  DrawCyberBar(Bitmap, FVol, '', 'AUDIO');
end;

procedure TFrmControl.BriScreenRedraw(Sender: TObject; Bitmap: TBGRABitmap);
begin
  DrawCyberBar(Bitmap, FBri, '', 'VISUAL');
end;

procedure TFrmControl.VolScreenMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var P: Double;
begin
  P := (X - 40) / (VolScreen.Width - 80);
  if P < 0 then P := 0; if P > 1 then P := 1;
  FVol := Round(P * 100);
  AddLog('AUDIO_LVL: ' + IntToStr(FVol));
  RunCmd('pamixer --set-volume ' + IntToStr(FVol));
  VolScreen.DiscardBitmap;
end;

procedure TFrmControl.BriScreenMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var P: Double;
begin
  P := (X - 40) / (BriScreen.Width - 80);
  if P < 0 then P := 0; if P > 1 then P := 1;
  FBri := Round(P * 100);
  AddLog('VISUAL_LVL: ' + IntToStr(FBri));
  RunCmd('brightnessctl set ' + IntToStr(FBri) + '%');
  BriScreen.DiscardBitmap;
end;

procedure TFrmControl.ScrWifiRedraw(Sender: TObject; Bitmap: TBGRABitmap);
var Status: string;
begin
  if FWifi then Status := 'ENABLED' else Status := 'DISABLED';
  DrawCyberButton(Bitmap, FWifi, '', 'NETWORK', Status);
end;

procedure TFrmControl.ScrWifiMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FWifi := not FWifi;
  if FWifi then AddLog('NET: SEARCHING...') else AddLog('NET: TERMINATED');
  ScrWifi.DiscardBitmap;
end;

procedure TFrmControl.ScrBlueRedraw(Sender: TObject; Bitmap: TBGRABitmap);
var Status: string;
begin
  if FBlue then Status := 'ACTIVE' else Status := 'OFFLINE';
  DrawCyberButton(Bitmap, FBlue, '', 'BLUETOOTH', Status);
end;

procedure TFrmControl.ScrBlueMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FBlue := not FBlue;
  AddLog('BT_STATE: TOGGLED');
  ScrBlue.DiscardBitmap;
end;

end.
