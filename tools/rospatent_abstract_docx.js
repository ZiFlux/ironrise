// Реферат программы для ЭВМ отдельным документом (docs/rospatent/IronRise_реферат.docx).
// Текст реферата и поля берутся из docs/rospatent/README.md — один источник.
// Пакет docx в проект не входит (см. tools/patent_docx.js):
//   NODE_PATH=<папка>/node_modules node tools/rospatent_abstract_docx.js
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, AlignmentType, Table, TableRow, TableCell,
  WidthType, BorderStyle,
} = require('docx');

const dir = path.join(__dirname, '..', 'docs', 'rospatent');
const readme = fs.readFileSync(path.join(dir, 'README.md'), 'utf8');

const abstract = readme.split('### Реферат')[1].split('## Файлы')[0].trim();
const field = (name) => {
  const row = readme.split(/\r?\n/).find((l) => l.startsWith(`| ${name} |`));
  if (!row) throw new Error(`Нет поля «${name}» в README`);
  return row.split('|')[2].trim();
};

const FONT = 'Times New Roman';
const SIZE = 28; // 14 пт
const mm = (v) => Math.round((v / 25.4) * 1440);
const text = (t, extra = {}) => new TextRun({ text: t, font: FONT, size: SIZE, ...extra });

// Поля для заполнения — строка с подчёркиванием, а не пустая клетка.
const BLANK = '________________________________________';

const rows = [
  ['Номер регистрации (свидетельства)', 'заполняет Роспатент'],
  ['Дата регистрации', 'заполняет Роспатент'],
  ['Номер и дата поступления заявки', 'заполняет Роспатент'],
  ['Автор(ы)', BLANK],
  ['Правообладатель(и)', BLANK],
  ['Название программы для ЭВМ', field('Название')],
  ['Год создания', field('Год создания')],
  ['Тип реализующей ЭВМ', field('Тип ЭВМ')],
  ['Язык программирования', field('Язык').replace('; если можно несколько — ', ', ')],
  ['Вид и версия операционной системы', field('ОС')],
  ['Объём программы для ЭВМ', field('Объём').replace(/\s*\(.*\)$/, '')],
];

const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const line = { style: BorderStyle.SINGLE, size: 4, color: '999999' };
const TABLE_W = mm(170);
const COL1 = mm(62);

const table = new Table({
  width: { size: TABLE_W, type: WidthType.DXA },
  columnWidths: [COL1, TABLE_W - COL1],
  rows: rows.map(([k, v]) => new TableRow({
    children: [
      new TableCell({
        width: { size: COL1, type: WidthType.DXA },
        borders: { top: none, left: none, right: none, bottom: line },
        margins: { top: 60, bottom: 60, right: 120 },
        children: [new Paragraph({ children: [text(k, { bold: true, size: 24 })] })],
      }),
      new TableCell({
        width: { size: TABLE_W - COL1, type: WidthType.DXA },
        borders: { top: none, left: none, right: none, bottom: line },
        margins: { top: 60, bottom: 60 },
        children: [new Paragraph({
          children: [text(v, { size: 24, ...(v === 'заполняет Роспатент' ? { color: '777777', italics: true } : {}) })],
        })],
      }),
    ],
  })),
});

const doc = new Document({
  styles: { default: { document: { run: { font: FONT, size: SIZE } } } },
  sections: [{
    properties: {
      page: { margin: { top: mm(20), bottom: mm(20), left: mm(25), right: mm(15) } },
    },
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 240 },
        children: [text('РЕФЕРАТ', { bold: true, size: 32 })],
      }),
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 360 },
        children: [text('программы для ЭВМ', { size: 26 })],
      }),
      table,
      new Paragraph({
        spacing: { before: 360, after: 120 },
        children: [text('Аннотация', { bold: true })],
      }),
      new Paragraph({
        alignment: AlignmentType.JUSTIFIED,
        spacing: { line: 360 },
        indent: { firstLine: mm(12.5) },
        children: [text(abstract)],
      }),
    ],
  }],
});

const out = path.join(dir, 'IronRise_реферат.docx');
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(out, buf);
  console.log(`${out}: ${buf.length} bytes, аннотация ${abstract.length} знаков`);
});
