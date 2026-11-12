// Собирает docs/patent/*.md и чертежи в один DOCX для подачи в Роспатент.
// Пакет docx в проект не входит: поставьте его в любую временную папку
// (npm i docx@9) и запускайте из корня репозитория:
//   NODE_PATH=<папка>/node_modules node tools/patent_docx.js
// Чертежи (PNG) рендерятся из SVG заранее, см. docs/patent/README.md.
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, ImageRun, AlignmentType, PageBreak,
  LevelFormat, Footer, PageNumber,
} = require('docx');

const dir = path.join(__dirname, '..', 'docs', 'patent');
const FONT = 'Times New Roman';
const SIZE = 28; // 14 пт
const mm = (v) => Math.round((v / 25.4) * 1440);

/** **жирный** внутри строки. */
const runs = (text, extra = {}) =>
  text.split(/(\*\*[^*]+\*\*)/).filter(Boolean).map((part) =>
    part.startsWith('**')
      ? new TextRun({ text: part.slice(2, -2), bold: true, ...extra })
      : new TextRun({ text: part, ...extra }));

const body = { spacing: { line: 360, after: 0 }, indent: { firstLine: mm(12.5) }, alignment: AlignmentType.JUSTIFIED };

/** Простой разбор нашего Markdown: заголовки, абзацы, списки «- » и «1. ». */
function convert(file, { firstPageBreak }) {
  const lines = fs.readFileSync(path.join(dir, file), 'utf8').split(/\r?\n/);
  const out = [];
  let first = true;
  let para = [];
  const flush = () => {
    if (!para.length) return;
    out.push(new Paragraph({ ...body, children: runs(para.join(' ')) }));
    para = [];
  };
  for (const raw of lines) {
    const line = raw.trimEnd();
    const h = line.match(/^(#{1,3})\s+(.*)$/);
    const bullet = line.match(/^\s*-\s+(.*)$/);
    const num = line.match(/^(\d+)\.\s+(.*)$/);
    if (!line.trim()) { flush(); continue; }
    if (h) {
      flush();
      const level = h[1].length;
      out.push(new Paragraph({
        alignment: level < 3 ? AlignmentType.CENTER : AlignmentType.LEFT,
        keepNext: true,
        pageBreakBefore: first && firstPageBreak,
        spacing: { before: level === 3 ? 240 : 120, after: 120, line: 360 },
        children: runs(h[2], { bold: level < 3 || level === 3 }),
      }));
      first = false;
    } else if (bullet) {
      flush();
      out.push(new Paragraph({
        numbering: { reference: 'dash', level: 0 },
        spacing: { line: 360, after: 0 },
        alignment: AlignmentType.JUSTIFIED,
        children: runs(bullet[1]),
      }));
    } else if (num && file.includes('формула')) {
      // Пункты формулы: номер и текст с абзацным отступом.
      flush();
      out.push(new Paragraph({ ...body, spacing: { line: 360, before: 120 }, children: runs(`${num[1]}. ${num[2]}`) }));
    } else if (num) {
      flush();
      out.push(new Paragraph({ ...body, children: runs(`${num[1]}. ${num[2]}`) }));
    } else {
      para.push(line.trim());
    }
  }
  flush();
  return out;
}

const figures = [
  ['фиг1_система.png', 800, 560],
  ['фиг2_алгоритм.png', 760, 1080],
  ['фиг3_пульс.png', 800, 660],
].map(([file, w, h], i) => {
  // Поле 170 × 247 мм; масштабируем в пределах.
  const maxW = 600; const maxH = 860;
  const k = Math.min(maxW / w, maxH / h);
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    pageBreakBefore: true,
    children: [new ImageRun({
      type: 'png',
      data: fs.readFileSync(path.join(dir, file)),
      transformation: { width: Math.round(w * k), height: Math.round(h * k) },
      altText: { title: `Фиг. ${i + 1}`, description: `Чертёж ${i + 1}`, name: file },
    })],
  });
});

const doc = new Document({
  creator: 'IronRise',
  title: 'Заявка на изобретение — черновик',
  styles: { default: { document: { run: { font: FONT, size: SIZE } } } },
  numbering: {
    config: [{
      reference: 'dash',
      levels: [{ level: 0, format: LevelFormat.BULLET, text: '–', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: mm(12.5), hanging: mm(6) } } } }],
    }],
  },
  sections: [{
    properties: {
      page: { size: { width: mm(210), height: mm(297) },
        margin: { top: mm(20), bottom: mm(20), left: mm(25), right: mm(20) } },
    },
    footers: { default: new Footer({ children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 24 })],
    })] }) },
    children: [
      ...convert('01_описание.md', { firstPageBreak: false }),
      ...convert('02_формула.md', { firstPageBreak: true }),
      ...convert('03_реферат.md', { firstPageBreak: true }),
      ...figures,
    ],
  }],
});

Packer.toBuffer(doc).then((buf) => {
  const out = path.join(dir, 'IronRise_заявка_изобретение.docx');
  fs.writeFileSync(out, buf);
  console.log(`${out}: ${buf.length} bytes`);
});
