import { ElectronAPI } from '@electron-toolkit/preload'

export interface IvetteApi {
  openDirDialog: () => Promise<string | null>
  listDir: (path: string) => Promise<string[]>
}

declare global {
  interface Window {
    electron: ElectronAPI
    api: IvetteApi
  }
}
