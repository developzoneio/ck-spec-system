export class EventEmitter<T> {
  private listeners: ((e: T) => any)[] = [];

  event = (listener: (e: T) => any) => {
    this.listeners.push(listener);
    return {
      dispose: () => {
        const index = this.listeners.indexOf(listener);
        if (index !== -1) {
          this.listeners.splice(index, 1);
        }
      }
    };
  };

  fire(data: T) {
    for (const listener of this.listeners) {
      listener(data);
    }
  }

  dispose() {
    this.listeners = [];
  }
}

export enum FileType {
  Unknown = 0,
  File = 1,
  Directory = 2,
  SymbolicLink = 64
}

export enum DiagnosticSeverity {
  Error = 0,
  Warning = 1,
  Information = 2,
  Hint = 3
}

export class Uri {
  public readonly scheme: string;
  public readonly authority: string;
  public readonly path: string;
  public readonly query: string;
  public readonly fragment: string;

  constructor(scheme: string, authority: string, path: string, query: string, fragment: string) {
    this.scheme = scheme;
    this.authority = authority;
    this.path = path;
    this.query = query;
    this.fragment = fragment;
  }

  static file(path: string): Uri {
    return new Uri('file', '', path, '', '');
  }

  static joinPath(base: Uri, ...pathSegments: string[]): Uri {
    const joinedPath = [base.path, ...pathSegments].join('/').replace(/\/+/g, '/');
    return new Uri(base.scheme, base.authority, joinedPath, base.query, base.fragment);
  }

  static parse(uriString: string): Uri {
    const parts = uriString.split(':');
    const scheme = parts[0];
    const path = parts.slice(1).join(':');
    return new Uri(scheme, '', path, '', '');
  }
}

export const workspace = {
  workspaceFolders: [
    {
      uri: Uri.file('/mock/workspace/root'),
      name: 'root',
      index: 0
    }
  ],
  fs: {
    stat: jest.fn(),
    readFile: jest.fn(),
    readDirectory: jest.fn(),
    writeFile: jest.fn(),
  },
  findFiles: jest.fn(),
  asRelativePath: (pathOrUri: string | Uri): string => {
    const p = typeof pathOrUri === 'string' ? pathOrUri : pathOrUri.path;
    return p.replace('/mock/workspace/root/', '');
  },
  registerTextDocumentContentProvider: jest.fn(() => ({ dispose: jest.fn() }))
};

export const commands = {
  executeCommand: jest.fn(),
};

export const window = {
  showInformationMessage: jest.fn(),
};

export const languages = {
  getDiagnostics: jest.fn(),
};
