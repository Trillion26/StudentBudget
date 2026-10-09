/// A small .xlsx writer: values, styles, merged cells and charts. It writes
/// just what the year report needs and is not a general spreadsheet
/// library. Rows and columns are 0-based in the API (row 0, column 0 is A1).
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

enum HAlign { left, center, right }

/// How one cell looks. Colours are `RRGGBB` hex.
class CellStyle {
  const CellStyle({
    this.bold = false,
    this.italic = false,
    this.size = 10,
    this.color = '1B2766',
    this.fill,
    this.align,
    this.numFmt,
    this.bottomBorder,
    this.wrap = false,
    this.indent = 0,
  });

  final bool bold;
  final bool italic;
  final double size;
  final String color;
  final String? fill;
  final HAlign? align;

  /// Excel number format, e.g. `"R"#,##0`.
  final String? numFmt;

  /// Colour of a thin line under the cell.
  final String? bottomBorder;
  final bool wrap;
  final int indent;

  CellStyle copyWith({
    bool? bold,
    bool? italic,
    double? size,
    String? color,
    String? fill,
    HAlign? align,
    String? numFmt,
    String? bottomBorder,
    bool? wrap,
    int? indent,
  }) => CellStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    size: size ?? this.size,
    color: color ?? this.color,
    fill: fill ?? this.fill,
    align: align ?? this.align,
    numFmt: numFmt ?? this.numFmt,
    bottomBorder: bottomBorder ?? this.bottomBorder,
    wrap: wrap ?? this.wrap,
    indent: indent ?? this.indent,
  );

  String get _fontKey => '$bold|$italic|$size|$color';
}

/// `B13` from row 12, column 1.
String cellRef(int row, int col) => '${columnName(col)}${row + 1}';

/// `A`, `B`, … `Z`, `AA`, …
String columnName(int col) {
  var n = col + 1;
  var name = '';
  while (n > 0) {
    name = String.fromCharCode(65 + (n - 1) % 26) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

class _Cell {
  _Cell(this.value, this.style);
  Object? value;
  CellStyle? style;
}

/// One worksheet.
class Sheet {
  Sheet(this.name, {this.tabColor});

  final String name;
  final String? tabColor;
  final Map<int, Map<int, _Cell>> _rows = {};
  final Map<int, double> _colWidths = {};
  final Map<int, double> _rowHeights = {};
  final List<String> _merges = [];
  final List<Chart> charts = [];

  /// Rows kept in view at the top while scrolling.
  int frozenRows = 0;

  /// Filter buttons on this range, e.g. `A1:G120`.
  String? autoFilter;

  /// Print on one page wide.
  bool fitToWidth = false;

  /// Sets a value (String, num or null) and style.
  void set(int row, int col, Object? value, [CellStyle? style]) {
    final cell = _rows.putIfAbsent(row, () => {}).putIfAbsent(col, () => _Cell(null, null));
    cell.value = value;
    if (style != null) cell.style = style;
  }

  /// Styles every cell in a block without changing values.
  void style(int r1, int c1, int r2, int c2, CellStyle style) {
    for (var r = r1; r <= r2; r++) {
      for (var c = c1; c <= c2; c++) {
        _rows.putIfAbsent(r, () => {}).putIfAbsent(c, () => _Cell(null, null)).style = style;
      }
    }
  }

  /// Merges a block, styles every cell in it (so fills and borders show)
  /// and puts [value] in the top-left cell.
  void merge(int r1, int c1, int r2, int c2, Object? value, CellStyle style) {
    this.style(r1, c1, r2, c2, style);
    set(r1, c1, value);
    if (r1 != r2 || c1 != c2) _merges.add('${cellRef(r1, c1)}:${cellRef(r2, c2)}');
  }

  void columnWidth(int col, double width) => _colWidths[col] = width;
  void rowHeight(int row, double height) => _rowHeights[row] = height;

  Object? valueAt(int row, int col) => _rows[row]?[col]?.value;

  bool isStyled(int row, int col) => _rows[row]?[col]?.style != null;

  /// `'Dashboard'!$B$13:$B$20`
  String range(int r1, int c1, int r2, int c2) =>
      "'${name.replaceAll("'", "''")}'!\$${columnName(c1)}\$${r1 + 1}:\$${columnName(c2)}\$${r2 + 1}";
}

/// A block of cells a chart reads, one column or one row.
class ChartRange {
  const ChartRange(this.sheet, this.r1, this.c1, this.r2, this.c2);

  final Sheet sheet;
  final int r1, c1, r2, c2;

  String get formula => sheet.range(r1, c1, r2, c2);

  List<Object?> get values => [
    for (var r = r1; r <= r2; r++)
      for (var c = c1; c <= c2; c++) sheet.valueAt(r, c),
  ];
}

class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.categories,
    required this.values,
    required this.color,
    this.pointColors,
  });

  final String name;
  final ChartRange categories;
  final ChartRange values;
  final String color;

  /// One colour per slice, for doughnut charts.
  final List<String>? pointColors;
}

enum ChartKind { bar, doughnut, line }

/// A chart placed over the cells from (fromRow, fromCol) up to, not
/// including, (toRow, toCol).
class Chart {
  const Chart({
    required this.kind,
    required this.series,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.showPercent = false,
    this.legendPosition = 't',
    this.valueFormat = '"R"#,##0',
  });

  final ChartKind kind;
  final List<ChartSeries> series;
  final int fromRow, fromCol, toRow, toCol;

  /// Doughnut slices show their share, e.g. 27%.
  final bool showPercent;

  /// `t`, `b`, `r` or `l`.
  final String legendPosition;
  final String valueFormat;
}

/// A workbook of [sheets], turned into .xlsx bytes by [encode].
class Workbook {
  final List<Sheet> sheets = [];
  String creator = '';

  Sheet addSheet(String name, {String? tabColor}) {
    final sheet = Sheet(name, tabColor: tabColor);
    sheets.add(sheet);
    return sheet;
  }

  Uint8List encode({DateTime? created}) {
    final styles = _Styles();
    final strings = _Strings();
    final archive = Archive();
    void add(String path, String xml) => archive.addFile(ArchiveFile.string(path, xml));

    var chartCount = 0;
    var drawingCount = 0;
    final overrides = StringBuffer();
    final sheetEntries = StringBuffer();
    final workbookRels = StringBuffer();
    final definedNames = StringBuffer();

    for (var i = 0; i < sheets.length; i++) {
      final sheet = sheets[i];
      final n = i + 1;
      String? drawingRel;
      if (sheet.charts.isNotEmpty) {
        drawingCount++;
        final drawingRels = StringBuffer();
        final anchors = StringBuffer();
        for (var k = 0; k < sheet.charts.length; k++) {
          chartCount++;
          final chart = sheet.charts[k];
          add('xl/charts/chart$chartCount.xml', _chartXml(chart));
          overrides.write(
            '<Override PartName="/xl/charts/chart$chartCount.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>',
          );
          drawingRels.write(
            '<Relationship Id="rId${k + 1}" Type="$_relBase/chart" Target="../charts/chart$chartCount.xml"/>',
          );
          anchors.write(_anchorXml(chart, k + 1, 'Chart $chartCount'));
        }
        add(
          'xl/drawings/drawing$drawingCount.xml',
          '$_xmlHead<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="$_aNs">$anchors</xdr:wsDr>',
        );
        add(
          'xl/drawings/_rels/drawing$drawingCount.xml.rels',
          '$_xmlHead<Relationships xmlns="$_pkgRelNs">$drawingRels</Relationships>',
        );
        add(
          'xl/worksheets/_rels/sheet$n.xml.rels',
          '$_xmlHead<Relationships xmlns="$_pkgRelNs"><Relationship Id="rId1" Type="$_relBase/drawing" Target="../drawings/drawing$drawingCount.xml"/></Relationships>',
        );
        overrides.write(
          '<Override PartName="/xl/drawings/drawing$drawingCount.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>',
        );
        drawingRel = 'rId1';
      }
      add('xl/worksheets/sheet$n.xml', _sheetXml(sheet, styles, strings, selected: i == 0, drawingRel: drawingRel));
      overrides.write(
        '<Override PartName="/xl/worksheets/sheet$n.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
      sheetEntries.write('<sheet name="${_esc(sheet.name)}" sheetId="$n" r:id="rId$n"/>');
      workbookRels.write('<Relationship Id="rId$n" Type="$_relBase/worksheet" Target="worksheets/sheet$n.xml"/>');
      if (sheet.autoFilter != null) {
        final parts = sheet.autoFilter!.split(':');
        final abs = parts
            .map((p) => p.replaceAllMapped(RegExp(r'([A-Z]+)(\d+)'), (m) => '\$${m[1]}\$${m[2]}'))
            .join(':');
        definedNames.write(
          "<definedName name=\"_xlnm._FilterDatabase\" localSheetId=\"$i\" hidden=\"1\">'${_esc(sheet.name.replaceAll("'", "''"))}'!$abs</definedName>",
        );
      }
    }

    final s = sheets.length;
    workbookRels
      ..write('<Relationship Id="rId${s + 1}" Type="$_relBase/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rId${s + 2}" Type="$_relBase/sharedStrings" Target="sharedStrings.xml"/>');

    add(
      'xl/workbook.xml',
      '$_xmlHead<workbook xmlns="$_mainNs" xmlns:r="$_relNs"><bookViews><workbookView activeTab="0"/></bookViews>'
          '<sheets>$sheetEntries</sheets>${definedNames.isEmpty ? '' : '<definedNames>$definedNames</definedNames>'}</workbook>',
    );
    add('xl/_rels/workbook.xml.rels', '$_xmlHead<Relationships xmlns="$_pkgRelNs">$workbookRels</Relationships>');
    add('xl/styles.xml', styles.xml());
    add('xl/sharedStrings.xml', strings.xml());

    final stamp = (created ?? DateTime.now()).toUtc().toIso8601String().split('.').first;
    add(
      'docProps/core.xml',
      '$_xmlHead<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:creator>${_esc(creator)}</dc:creator>'
          '<dcterms:created xsi:type="dcterms:W3CDTF">${stamp}Z</dcterms:created></cp:coreProperties>',
    );
    add(
      'docProps/app.xml',
      '$_xmlHead<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>${_esc(creator)}</Application></Properties>',
    );
    add(
      '_rels/.rels',
      '$_xmlHead<Relationships xmlns="$_pkgRelNs">'
          '<Relationship Id="rId1" Type="$_relBase/officeDocument" Target="xl/workbook.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
          '<Relationship Id="rId3" Type="$_relBase/extended-properties" Target="docProps/app.xml"/>'
          '</Relationships>',
    );
    add(
      '[Content_Types].xml',
      '$_xmlHead<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
          '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
          '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
          '$overrides</Types>',
    );

    return ZipEncoder().encodeBytes(archive);
  }
}

const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _relBase = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkgRelNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _cNs = 'http://schemas.openxmlformats.org/drawingml/2006/chart';

/// Escapes XML text and drops control characters XML can't hold.
String _esc(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _num(num value) {
  if (value is int || value == value.roundToDouble() && value.abs() < 1e15) return value.round().toString();
  return value.toString();
}

class _Strings {
  final Map<String, int> _index = {};
  final List<String> _list = [];
  int _count = 0;

  int id(String value) {
    _count++;
    return _index.putIfAbsent(value, () {
      _list.add(value);
      return _list.length - 1;
    });
  }

  String xml() {
    final out = StringBuffer('$_xmlHead<sst xmlns="$_mainNs" count="$_count" uniqueCount="${_list.length}">');
    for (final s in _list) {
      out.write('<si><t xml:space="preserve">${_esc(s)}</t></si>');
    }
    out.write('</sst>');
    return out.toString();
  }
}

class _Styles {
  final Map<String, int> _numFmts = {};
  final List<String> _fonts = [
    '<font><sz val="10"/><color rgb="FF1B2766"/><name val="Arial"/><family val="2"/></font>',
  ];
  final Map<String, int> _fontIds = {};
  final List<String> _fills = [
    '<fill><patternFill patternType="none"/></fill>',
    '<fill><patternFill patternType="gray125"/></fill>',
  ];
  final Map<String, int> _fillIds = {};
  final List<String> _borders = ['<border><left/><right/><top/><bottom/><diagonal/></border>'];
  final Map<String, int> _borderIds = {};
  final List<String> _xfs = ['<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'];
  final Map<String, int> _xfIds = {};

  int id(CellStyle s) {
    final numFmtId = s.numFmt == null ? 0 : _numFmts.putIfAbsent(s.numFmt!, () => 164 + _numFmts.length);
    final fontId = _fontIds.putIfAbsent(s._fontKey, () {
      _fonts.add(
        '<font>${s.bold ? '<b/>' : ''}${s.italic ? '<i/>' : ''}<sz val="${_num(s.size)}"/>'
        '<color rgb="FF${s.color}"/><name val="Arial"/><family val="2"/></font>',
      );
      return _fonts.length - 1;
    });
    final fillId = s.fill == null
        ? 0
        : _fillIds.putIfAbsent(s.fill!, () {
            _fills.add(
              '<fill><patternFill patternType="solid"><fgColor rgb="FF${s.fill}"/><bgColor indexed="64"/></patternFill></fill>',
            );
            return _fills.length - 1;
          });
    final borderId = s.bottomBorder == null
        ? 0
        : _borderIds.putIfAbsent(s.bottomBorder!, () {
            _borders.add(
              '<border><left/><right/><top/><bottom style="thin"><color rgb="FF${s.bottomBorder}"/></bottom><diagonal/></border>',
            );
            return _borders.length - 1;
          });
    final horizontal = s.align == null ? '' : ' horizontal="${s.align!.name}"';
    final alignment =
        '<alignment$horizontal vertical="center"${s.wrap ? ' wrapText="1"' : ''}${s.indent > 0 ? ' indent="${s.indent}"' : ''}/>';
    final key = '$numFmtId|$fontId|$fillId|$borderId|$alignment';
    return _xfIds.putIfAbsent(key, () {
      _xfs.add(
        '<xf numFmtId="$numFmtId" fontId="$fontId" fillId="$fillId" borderId="$borderId" xfId="0" '
        'applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">$alignment</xf>',
      );
      return _xfs.length - 1;
    });
  }

  String xml() {
    final numFmts = _numFmts.entries.map((e) => '<numFmt numFmtId="${e.value}" formatCode="${_esc(e.key)}"/>').join();
    return '$_xmlHead<styleSheet xmlns="$_mainNs">'
        '${_numFmts.isEmpty ? '' : '<numFmts count="${_numFmts.length}">$numFmts</numFmts>'}'
        '<fonts count="${_fonts.length}">${_fonts.join()}</fonts>'
        '<fills count="${_fills.length}">${_fills.join()}</fills>'
        '<borders count="${_borders.length}">${_borders.join()}</borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="${_xfs.length}">${_xfs.join()}</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>';
  }
}

String _sheetXml(Sheet sheet, _Styles styles, _Strings strings, {required bool selected, String? drawingRel}) {
  final out = StringBuffer('$_xmlHead<worksheet xmlns="$_mainNs" xmlns:r="$_relNs">');
  final tab = sheet.tabColor == null ? '' : '<tabColor rgb="FF${sheet.tabColor}"/>';
  final fit = sheet.fitToWidth ? '<pageSetUpPr fitToPage="1"/>' : '';
  if (tab.isNotEmpty || fit.isNotEmpty) out.write('<sheetPr>$tab$fit</sheetPr>');

  out.write('<sheetViews><sheetView workbookViewId="0" showGridLines="0"${selected ? ' tabSelected="1"' : ''}>');
  if (sheet.frozenRows > 0) {
    out.write(
      '<pane ySplit="${sheet.frozenRows}" topLeftCell="A${sheet.frozenRows + 1}" activePane="bottomLeft" state="frozen"/>',
    );
  }
  out.write('</sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/>');

  if (sheet._colWidths.isNotEmpty) {
    out.write('<cols>');
    for (final col in sheet._colWidths.keys.toList()..sort()) {
      out.write('<col min="${col + 1}" max="${col + 1}" width="${_num(sheet._colWidths[col]!)}" customWidth="1"/>');
    }
    out.write('</cols>');
  }

  out.write('<sheetData>');
  final rowIds = {...sheet._rows.keys, ...sheet._rowHeights.keys}.toList()..sort();
  for (final r in rowIds) {
    final height = sheet._rowHeights[r];
    out.write('<row r="${r + 1}"${height == null ? '' : ' ht="${_num(height)}" customHeight="1"'}>');
    final cells = sheet._rows[r] ?? const {};
    for (final c in cells.keys.toList()..sort()) {
      final cell = cells[c]!;
      final ref = cellRef(r, c);
      final s = cell.style == null ? '' : ' s="${styles.id(cell.style!)}"';
      final v = cell.value;
      if (v == null) {
        out.write('<c r="$ref"$s/>');
      } else if (v is num) {
        out.write('<c r="$ref"$s><v>${_num(v)}</v></c>');
      } else {
        out.write('<c r="$ref"$s t="s"><v>${strings.id(v.toString())}</v></c>');
      }
    }
    out.write('</row>');
  }
  out.write('</sheetData>');

  if (sheet.autoFilter != null) out.write('<autoFilter ref="${sheet.autoFilter}"/>');
  if (sheet._merges.isNotEmpty) {
    out.write('<mergeCells count="${sheet._merges.length}">');
    for (final m in sheet._merges) {
      out.write('<mergeCell ref="$m"/>');
    }
    out.write('</mergeCells>');
  }
  out.write('<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>');
  if (sheet.fitToWidth) out.write('<pageSetup paperSize="9" orientation="portrait" fitToWidth="1" fitToHeight="0"/>');
  if (drawingRel != null) out.write('<drawing r:id="$drawingRel"/>');
  out.write('</worksheet>');
  return out.toString();
}

String _anchorXml(Chart chart, int relId, String name) =>
    '<xdr:twoCellAnchor editAs="oneCell">'
    '<xdr:from><xdr:col>${chart.fromCol}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${chart.fromRow}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>'
    '<xdr:to><xdr:col>${chart.toCol}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${chart.toRow}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'
    '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${relId + 1}" name="$name"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
    '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
    '<a:graphic><a:graphicData uri="$_cNs"><c:chart xmlns:c="$_cNs" xmlns:r="$_relNs" r:id="rId$relId"/></a:graphicData></a:graphic>'
    '</xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>';

const _chartText = '5A6290';
const _chartLine = 'DFE2EE';

String _fill(String color) => '<a:solidFill><a:srgbClr val="$color"/></a:solidFill>';

String _txPr({int size = 800, String color = _chartText}) =>
    '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="$size">${_fill(color)}</a:defRPr></a:pPr><a:endParaRPr lang="en-US"/></a:p></c:txPr>';

String _strRef(ChartRange range) {
  final values = range.values;
  final pts = StringBuffer();
  for (var i = 0; i < values.length; i++) {
    pts.write('<c:pt idx="$i"><c:v>${_esc('${values[i] ?? ''}')}</c:v></c:pt>');
  }
  return '<c:strRef><c:f>${_esc(range.formula)}</c:f><c:strCache><c:ptCount val="${values.length}"/>$pts</c:strCache></c:strRef>';
}

String _numRef(ChartRange range) {
  final values = range.values;
  final pts = StringBuffer();
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v is num) pts.write('<c:pt idx="$i"><c:v>${_num(v)}</c:v></c:pt>');
  }
  return '<c:numRef><c:f>${_esc(range.formula)}</c:f><c:numCache><c:formatCode>General</c:formatCode>'
      '<c:ptCount val="${values.length}"/>$pts</c:numCache></c:numRef>';
}

String _noLabels({bool percent = false}) =>
    '${percent ? '<c:numFmt formatCode="0%" sourceLinked="0"/><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>${_txPr(size: 800, color: 'FFFFFF')}' : ''}'
    '<c:showLegendKey val="0"/><c:showVal val="0"/><c:showCatName val="0"/><c:showSerName val="0"/>'
    '<c:showPercent val="${percent ? 1 : 0}"/><c:showBubbleSize val="0"/>';

String _axes({required bool horizontal, required String valueFormat}) {
  final line = '<c:spPr><a:ln w="9525">${_fill(_chartLine)}</a:ln></c:spPr>';
  final noLine = '<c:spPr><a:ln><a:noFill/></a:ln></c:spPr>';
  final grid = '<c:majorGridlines><c:spPr><a:ln w="6350">${_fill(_chartLine)}</a:ln></c:spPr></c:majorGridlines>';
  return '<c:catAx><c:axId val="1001"/><c:scaling><c:orientation val="${horizontal ? 'maxMin' : 'minMax'}"/></c:scaling>'
      '<c:delete val="0"/><c:axPos val="${horizontal ? 'l' : 'b'}"/><c:numFmt formatCode="General" sourceLinked="0"/>'
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="low"/>$line${_txPr()}'
      '<c:crossAx val="1002"/><c:crosses val="${horizontal ? 'max' : 'autoZero'}"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/></c:catAx>'
      '<c:valAx><c:axId val="1002"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/>'
      '<c:axPos val="${horizontal ? 'b' : 'l'}"/>$grid<c:numFmt formatCode="${_esc(valueFormat)}" sourceLinked="0"/>'
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>$noLine${_txPr()}'
      '<c:crossAx val="1001"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx>';
}

String _chartXml(Chart chart) {
  final plot = StringBuffer();
  switch (chart.kind) {
    case ChartKind.bar:
      plot.write('<c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/><c:varyColors val="0"/>');
      for (var i = 0; i < chart.series.length; i++) {
        final s = chart.series[i];
        plot.write(
          '<c:ser><c:idx val="$i"/><c:order val="$i"/><c:tx><c:v>${_esc(s.name)}</c:v></c:tx>'
          '<c:spPr>${_fill(s.color)}</c:spPr><c:invertIfNegative val="0"/>'
          '<c:cat>${_strRef(s.categories)}</c:cat><c:val>${_numRef(s.values)}</c:val></c:ser>',
        );
      }
      plot.write('<c:gapWidth val="50"/><c:axId val="1001"/><c:axId val="1002"/></c:barChart>');
      plot.write(_axes(horizontal: true, valueFormat: chart.valueFormat));
    case ChartKind.line:
      plot.write('<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>');
      for (var i = 0; i < chart.series.length; i++) {
        final s = chart.series[i];
        plot.write(
          '<c:ser><c:idx val="$i"/><c:order val="$i"/><c:tx><c:v>${_esc(s.name)}</c:v></c:tx>'
          '<c:spPr><a:ln w="28575" cap="rnd">${_fill(s.color)}<a:round/></a:ln></c:spPr><c:marker><c:symbol val="none"/></c:marker>'
          '<c:cat>${_strRef(s.categories)}</c:cat><c:val>${_numRef(s.values)}</c:val><c:smooth val="0"/></c:ser>',
        );
      }
      plot.write('<c:marker val="1"/><c:axId val="1001"/><c:axId val="1002"/></c:lineChart>');
      plot.write(_axes(horizontal: false, valueFormat: chart.valueFormat));
    case ChartKind.doughnut:
      plot.write('<c:doughnutChart><c:varyColors val="1"/>');
      for (var i = 0; i < chart.series.length; i++) {
        final s = chart.series[i];
        plot.write('<c:ser><c:idx val="$i"/><c:order val="$i"/><c:tx><c:v>${_esc(s.name)}</c:v></c:tx>');
        final colors = s.pointColors ?? const [];
        for (var p = 0; p < colors.length; p++) {
          plot.write(
            '<c:dPt><c:idx val="$p"/><c:bubble3D val="0"/><c:spPr>${_fill(colors[p])}'
            '<a:ln w="12700">${_fill('FFFFFF')}</a:ln></c:spPr></c:dPt>',
          );
        }
        if (chart.showPercent) plot.write('<c:dLbls>${_noLabels(percent: true)}<c:showLeaderLines val="0"/></c:dLbls>');
        plot.write('<c:cat>${_strRef(s.categories)}</c:cat><c:val>${_numRef(s.values)}</c:val></c:ser>');
      }
      plot.write(
        '<c:dLbls>${_noLabels()}<c:showLeaderLines val="0"/></c:dLbls><c:firstSliceAng val="0"/><c:holeSize val="55"/></c:doughnutChart>',
      );
  }

  return '$_xmlHead<c:chartSpace xmlns:c="$_cNs" xmlns:a="$_aNs" xmlns:r="$_relNs">'
      '<c:roundedCorners val="0"/><c:chart><c:autoTitleDeleted val="1"/><c:plotArea><c:layout/>$plot'
      '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr></c:plotArea>'
      '<c:legend><c:legendPos val="${chart.legendPosition}"/><c:overlay val="0"/>${_txPr()}</c:legend>'
      '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>'
      '<c:spPr>${_fill('FFFFFF')}<a:ln><a:noFill/></a:ln></c:spPr>${_txPr()}</c:chartSpace>';
}
