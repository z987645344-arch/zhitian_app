const List<String> toolboxConvertibleExtensions = [
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
];

const List<String> toolboxPdfExtensions = ['pdf'];

class ToolboxConversionOption {
  const ToolboxConversionOption({
    required this.id,
    required this.label,
    required this.extensions,
    required this.targetFormat,
  });

  final String id;
  final String label;
  final List<String> extensions;
  final String targetFormat;
}

const List<ToolboxConversionOption> toolboxConversionOptions = [
  ToolboxConversionOption(
    id: 'pdf_to_word',
    label: 'PDF转Word',
    extensions: ['pdf'],
    targetFormat: 'docx',
  ),
  ToolboxConversionOption(
    id: 'pdf_to_excel',
    label: 'PDF转Excel',
    extensions: ['pdf'],
    targetFormat: 'xlsx',
  ),
  ToolboxConversionOption(
    id: 'pdf_to_ppt',
    label: 'PDF转PPT',
    extensions: ['pdf'],
    targetFormat: 'pptx',
  ),
  ToolboxConversionOption(
    id: 'word_to_pdf',
    label: 'Word转PDF',
    extensions: ['doc', 'docx'],
    targetFormat: 'pdf',
  ),
  ToolboxConversionOption(
    id: 'excel_to_pdf',
    label: 'Excel转PDF',
    extensions: ['xls', 'xlsx'],
    targetFormat: 'pdf',
  ),
  ToolboxConversionOption(
    id: 'ppt_to_pdf',
    label: 'PPT转PDF',
    extensions: ['ppt', 'pptx'],
    targetFormat: 'pdf',
  ),
];
