unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  cmem,Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, BCPanel,
  BCLabel, BCButton, DTAnalogClock,Process, Unix, BaseUnix, StrUtils;

type

  { TForm1 }

  TForm1 = class(TForm)
    BCButton1: TBCButton;
    BCButton2: TBCButton;
    LblBat: TBCLabel;
    LblClock: TBCLabel;
    LblCPU: TBCLabel;
    LblRAM: TBCLabel;
    LeftPanel: TBCPanel;
    RightPanel: TBCPanel;
    Timer1: TTimer;
    procedure BCButton1Click(Sender: TObject);
    procedure BCButton2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;


implementation

{$R *.lfm}

// Функция чтения RAM (исправленная)
function GetRAMUsage: string;
var
  SL: TStringList;
  Total, Available: Int64;
  I: Integer;
  S: string;
begin
  Result := 'RAM: ?';
  SL := TStringList.Create;
  try
    if FileExists('/proc/meminfo') then
    begin
      SL.LoadFromFile('/proc/meminfo');
      Total := 0; Available := 0;

      for I := 0 to SL.Count - 1 do
      begin
        S := SL[I];
        // Нормализуем строку: меняем табы и множественные пробелы на один пробел
        S := StringReplace(S, ':', ' ', [rfReplaceAll]);
        while Pos('  ', S) > 0 do
          S := StringReplace(S, '  ', ' ', [rfReplaceAll]);

        // Теперь S выглядит как "MemTotal 16000 kB"
        // ExtractWord(2, ...) возьмет число

        if Pos('MemTotal', SL[I]) = 1 then
          Total := StrToInt64Def(ExtractWord(2, S, [' ']), 0);

        if Pos('MemAvailable', SL[I]) = 1 then
          Available := StrToInt64Def(ExtractWord(2, S, [' ']), 0);
      end;

      if Total > 0 then
        Result := Format('RAM: %d%%', [Round(((Total - Available) / Total) * 100)]);
    end;
  finally
    SL.Free;
  end;
end;

// Функция чтения загрузки CPU через файл (Надежная)
function GetLoadAvgStr: string;
var
  F: TextFile;
  S: string;
begin
  try
    AssignFile(F, '/proc/loadavg');
    Reset(F);
    Readln(F, S);
    CloseFile(F);
    // Берем первое число (загрузка за 1 минуту)
    // Строка вида: "0.54 0.40 ..."
    Result := 'CPU Load: ' + ExtractWord(1, S, [' ']);
  except
    Result := 'CPU: ?';
  end;
end;


function GetBatteryStatus: string;
var
  CapPath, StatPath: string;
  Capacity: Integer;
  Status: TStringList;
  Icon: string;
begin
  // Обычно батарея называется BAT0 или BAT1
  CapPath := '/sys/class/power_supply/BATT/capacity';
  StatPath := '/sys/class/power_supply/BATT/status';

  if not FileExists(CapPath) then
  begin
    Result := ''; // Если батареи нет (ПК), возвращаем пустоту
    Exit;
  end;

  // Читаем процент (одной строчкой через TStringList проще всего)
  Status := TStringList.Create;
  try
    Status.LoadFromFile(CapPath);
    Capacity := StrToIntDef(Trim(Status[0]), 0);

    Status.LoadFromFile(StatPath); // Charging / Discharging / Full

    // Выбираем иконку (Nerd Fonts)
    if Pos('Charging', Status[0]) > 0 then
      Icon := '' // Молния
    else if Capacity > 90 then Icon := ''
    else if Capacity > 60 then Icon := ''
    else if Capacity > 40 then Icon := ''
    else if Capacity > 10 then Icon := ''
    else Icon := ''; // Пустая

    Result := Format('%s %d%%', [Icon, Capacity]);
  finally
    Status.Free;
  end;
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Жестко задаем размеры и позицию
  Self.Left := 0;
  Self.Top := 0;
  Self.Width := Screen.Width; // На всю ширину экрана
  Self.Height := 32;          // Высота бара (как у Polybar)
    // Чтобы кнопки меню были слева, а статы справа,
  // иногда полезно принудительно обновить выравнивание:
  LeftPanel.Width := 120;
  RightPanel.Width := 300;

  // Цвет фона формы (если вдруг BCPanel не закрыл всё)
  Self.Color := $00282828; // Темно-серый (формат $00BBGGRR)
end;

procedure TForm1.BCButton2Click(Sender: TObject);
var
  Proc: TProcess;
begin
  Proc := TProcess.Create(nil);
  try
    // Замени 'alacritty' на свой терминал!
    Proc.Executable := 'alacritty';
    Proc.Options := [poDetached]; // Запустить и забыть (не ждать закрытия)
    Proc.Execute;
  finally
    Proc.Free;
  end;
end;

procedure TForm1.BCButton1Click(Sender: TObject);
var
  Proc: TProcess;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := 'wofi';
    Proc.Parameters.Add('--show');
    Proc.Parameters.Add('drun');
    Proc.Options := [poDetached];
    Proc.Execute;
  except
    ShowMessage('Wofi not installed?');
  end;
  Proc.Free;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
    // Часы
  LblClock.Caption := '   '+ FormatDateTime('hh:nn', Now);

  // Память
  LblRAM.Caption := ' ' + GetRAMUsage;

  // Процессор (Load Average)
  LblCPU.Caption := ' '+ GetLoadAvgStr;


  LblBat.Caption := GetBatteryStatus;


end;

end.

