global.URL.createObjectURL = vi.fn((file: Blob) => {
  return `blob://mock/${file instanceof Blob ? (file.type.length > 0 ? file.type : 'unknown') : 'unknown'}`;
});
global.URL.revokeObjectURL = vi.fn((uri: string) => {
  
});
Object.defineProperty(HTMLElement.prototype, 'offsetWidth', { configurable: true, value: 100 });
Object.defineProperty(HTMLElement.prototype, 'offsetHeight', { configurable: true, value: 20 });
