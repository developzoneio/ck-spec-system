import { DiffContentProvider } from './diff-content-provider';
import { Uri } from 'vscode';

describe('DiffContentProvider', () => {
  let provider: DiffContentProvider;
  
  beforeEach(() => {
    provider = new DiffContentProvider();
  });

  it('should store and provide content', () => {
    const uri = Uri.parse('specwright-diff:test.txt');
    provider.setContent(uri, 'hello world');
    expect(provider.provideTextDocumentContent(uri)).toBe('hello world');
  });

  it('should return empty string for unknown uri', () => {
    const uri = Uri.parse('specwright-diff:unknown.txt');
    expect(provider.provideTextDocumentContent(uri)).toBe('');
  });

  it('should remove content', () => {
    const uri = Uri.parse('specwright-diff:test.txt');
    provider.setContent(uri, 'hello world');
    provider.removeContent(uri);
    expect(provider.provideTextDocumentContent(uri)).toBe('');
  });

  it('should clear all on dispose', () => {
    const uri1 = Uri.parse('specwright-diff:test1.txt');
    const uri2 = Uri.parse('specwright-diff:test2.txt');
    provider.setContent(uri1, 'hello');
    provider.setContent(uri2, 'world');
    
    provider.dispose();
    
    expect(provider.provideTextDocumentContent(uri1)).toBe('');
    expect(provider.provideTextDocumentContent(uri2)).toBe('');
  });

  it('should fire onDidChange when content is set', () => {
    const listener = jest.fn();
    provider.onDidChange(listener);
    
    const uri = Uri.parse('specwright-diff:test.txt');
    provider.setContent(uri, 'hello');
    
    expect(listener).toHaveBeenCalledWith(uri);
  });
});
