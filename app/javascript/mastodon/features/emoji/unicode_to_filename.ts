export const unicodeToFilename = (str: string) => {
  let result = '';
  let charCode = 0;
  let p = 0;
  let i = 0;
  while (i < str.length) {
    charCode = str.charCodeAt(i++);
    if (p) {
      if (result.length > 0) {
        result += '-';
      }
      result += (0x10000 + ((p - 0xd800) << 10) + (charCode - 0xdc00)).toString(
        16,
      );
      p = 0;
    } else if (0xd800 <= charCode && charCode <= 0xdbff) {
      p = charCode;
    } else {
      if (result.length > 0) {
        result += '-';
      }
      result += charCode.toString(16);
    }
  }
  return result;
};
