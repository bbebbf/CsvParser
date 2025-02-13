unit TestCsvParser;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestCsvParser = class
  public
    // Sample Methods
    // Simple single Test
    [Test]
    procedure Test1;
  end;

implementation

uses CsvParser;

procedure TTestCsvParser.Test1;
begin
  var lCsvParser := TCsvParser.Create;
  try
    lCsvParser.Parse('1,2,3');
  finally
    lCsvParser.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCsvParser);

end.
