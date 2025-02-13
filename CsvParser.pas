unit CsvParser;

interface

uses System.Classes, System.Generics.Collections;

type
  TCsvDocumentField = class
  strict private
    fContent: string;
  public
    constructor Create(const aContent: string);
    property Content: string read fContent;
  end;

  TCsvDocumentRow = class
  strict private
    fFields: TObjectList<TCsvDocumentField>;
  public
    constructor Create;
    destructor Destroy; override;
    function AddField(const aFieldContent: string): TCsvDocumentField;
    property Fields: TObjectList<TCsvDocumentField> read fFields;
  end;

  TCsvDocument = class
  strict private
    fErrors: TStrings;
    fHeader: TCsvDocumentRow;
    fRecords: TObjectList<TCsvDocumentRow>;
    fFieldCount: Integer;
    function GetHeader: TCsvDocumentRow;
    function GetRecords: TObjectList<TCsvDocumentRow>;
  private
    function GetErrors: TStrings;
  public
    destructor Destroy; override;
    property Header: TCsvDocumentRow read GetHeader;
    property Records: TObjectList<TCsvDocumentRow> read GetRecords;
    property Errors: TStrings read GetErrors;
    property FieldCount: Integer read fFieldCount write fFieldCount;
  end;

  TCsvParserRowCreatorCallback = reference to function(const aDocument: TCsvDocument;
    const aRowIndex: Integer): TCsvDocumentRow;

  // https://datatracker.ietf.org/doc/html/rfc4180
  TCsvParser = class
  strict private
    const
      CRChar: Char = #$D;
      LFChar: Char = #$A;
    var
    fFieldSepChar: Char;
    fEscapeChar: Char;
    fHeaderIncluded: Boolean;
    function ParseInternal(const aCsvContentReader: TTextReader;
      const aRowCreatorCallback: TCsvParserRowCreatorCallback): TCsvDocument;
    function ReadNextChar(const aCsvContentReader: TTextReader; const aMoveCursor: Boolean; out aChar: Char): Boolean;
  public
    constructor Create;
    function Parse(const aCsvContent: string): TCsvDocument; overload;
    function Parse(const aCsvContentReader: TTextReader): TCsvDocument; overload;
    property FieldSepChar: Char read fFieldSepChar write fFieldSepChar;
    property EscapeChar: Char read fEscapeChar write fEscapeChar;
    property HeaderIncluded: Boolean read fHeaderIncluded write fHeaderIncluded;
  end;

implementation

{ TCsvParser }

constructor TCsvParser.Create;
begin
  inherited Create;
  fFieldSepChar := ',';
  fEscapeChar := '"';
end;

function TCsvParser.Parse(const aCsvContent: string): TCsvDocument;
begin
  var lStringReader := TStringReader.Create(aCsvContent);
  try
    Result := Parse(lStringReader);
  finally
    lStringReader.Free;
  end;
end;

function TCsvParser.Parse(const aCsvContentReader: TTextReader): TCsvDocument;
begin
  aCsvContentReader.Rewind;
  Result := ParseInternal(aCsvContentReader,
    function(const aDocument: TCsvDocument; const aRowIndex: Integer): TCsvDocumentRow
    begin
      if (aRowIndex = 0) and fHeaderIncluded then
      begin
        Result := aDocument.Header;
      end
      else
      begin
        Result := TCsvDocumentRow.Create;
        aDocument.Records.Add(Result);
      end;
    end
  );
end;

function TCsvParser.ParseInternal(const aCsvContentReader: TTextReader;
  const aRowCreatorCallback: TCsvParserRowCreatorCallback): TCsvDocument;
var
  lInEscapedField: Boolean;
  lEscapedFieldLeft: Boolean;
  lCurrentRowIndex: Integer;
  lCurrentRow: TCsvDocumentRow;
  lCurrentFieldContent: string;
  lCurrentChar: Char;
  lNextPeekedChar: Char;

  procedure StartNextField;
  begin
    lCurrentFieldContent := '';
    lInEscapedField := False;
    lEscapedFieldLeft := False;
  end;

begin
  Result := TCsvDocument.Create;
  lCurrentRowIndex := 0;
  lCurrentRow := aRowCreatorCallback(Result, lCurrentRowIndex);
  StartNextField;
  while ReadNextChar(aCsvContentReader, True, lCurrentChar) do
  begin
    if lCurrentChar = fEscapeChar then
    begin
      if lInEscapedField then
      begin
        if ReadNextChar(aCsvContentReader, False, lNextPeekedChar) and (lNextPeekedChar = fEscapeChar) then
        begin
          lCurrentFieldContent := lCurrentFieldContent + lCurrentChar;
          aCsvContentReader.Read;
        end
        else
        begin
          lInEscapedField := False;
          lEscapedFieldLeft := True;
        end;
      end
      else
      begin
        lInEscapedField := True;
        if Length(lCurrentFieldContent) > 0 then
        begin
          Result.Errors.Add('Escaping starts after field content "' + lCurrentFieldContent + '".');
        end;
      end;
    end
    else if lInEscapedField then
    begin
      lCurrentFieldContent := lCurrentFieldContent + lCurrentChar;
    end
    else if lCurrentChar = fFieldSepChar then
    begin
      lCurrentRow.AddField(lCurrentFieldContent); // Finish last field
      StartNextField;
    end
    else if (lCurrentChar = CRChar) or (lCurrentChar = LFChar) then
    begin
      Inc(lCurrentRowIndex);
      lCurrentRow := aRowCreatorCallback(Result, lCurrentRowIndex);
      StartNextField;
      if lCurrentChar = CRChar then
      begin
        if ReadNextChar(aCsvContentReader, False, lNextPeekedChar) and (lNextPeekedChar = LFChar) then
        begin
          aCsvContentReader.Read; // skip the found LFChar
        end
      end;
    end
    else
    begin
      if lEscapedFieldLeft then
      begin
        Result.Errors.Add('Char "' + lCurrentChar + '" after escaped field content.');
      end
      else
      begin
        lCurrentFieldContent := lCurrentFieldContent + lCurrentChar;
      end;
    end;
  end;
  if lInEscapedField then
  begin
    Result.Errors.Add('Escaped field not closed. Field content "' + lCurrentFieldContent + '"');
  end;
  lCurrentRow.AddField(lCurrentFieldContent);
end;

function TCsvParser.ReadNextChar(const aCsvContentReader: TTextReader; const aMoveCursor: Boolean; out aChar: Char): Boolean;
var
  lNextChar: Integer;
begin
  aChar := #0;
  if aMoveCursor then
    lNextChar := aCsvContentReader.Read
  else
    lNextChar := aCsvContentReader.Peek;
  if lNextChar < 0 then
    Exit(False);
  aChar := Char(lNextChar);
  Result := True;
end;

{ TCsvDocument }

destructor TCsvDocument.Destroy;
begin
  fHeader.Free;
  fRecords.Free;
  fErrors.Free;
  inherited;
end;

function TCsvDocument.GetErrors: TStrings;
begin
  if Assigned(fErrors) then
    Exit(fErrors);
  fErrors := TStringList.Create;
  Result := fErrors;
end;

function TCsvDocument.GetHeader: TCsvDocumentRow;
begin
  if Assigned(fHeader) then
    Exit(fHeader);
  fHeader := TCsvDocumentRow.Create;
  Result := fHeader;
end;

function TCsvDocument.GetRecords: TObjectList<TCsvDocumentRow>;
begin
  if Assigned(fRecords) then
    Exit(fRecords);
  fRecords := TObjectList<TCsvDocumentRow>.Create;
  Result := fRecords;
end;

{ TCsvDocumentRow }

constructor TCsvDocumentRow.Create;
begin
  inherited Create;
  fFields := TObjectList<TCsvDocumentField>.Create;
end;

destructor TCsvDocumentRow.Destroy;
begin
  fFields.Free;
  inherited;
end;

function TCsvDocumentRow.AddField(const aFieldContent: string): TCsvDocumentField;
begin
  Result := TCsvDocumentField.Create(aFieldContent);
end;

{ TCsvDocumentField }

constructor TCsvDocumentField.Create(const aContent: string);
begin
  inherited Create;
  fContent := aContent;
end;

end.
