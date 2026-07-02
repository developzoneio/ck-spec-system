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
