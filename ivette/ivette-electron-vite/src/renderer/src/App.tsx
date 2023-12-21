import { useEffect, useState } from 'react'
const fs = window.require('fs')

function App(): JSX.Element {
  const [content, setContent] = useState<string[]>([])

  useEffect(() => {
    const test = fs.readdirSync('.') as string[]
    setContent(test)
  }, [])

  return (
    <div>
      <button
        className="btn"
        onClick={async () => {
          const pwd = await window.api.openDirDialog()
          if (pwd) {
            const list = await window.api.listDir(pwd)
            setContent(list)
          }
        }}
      >
        Select a directory
      </button>
      <ul>
        {content.map((c) => (
          <li>{c}</li>
        ))}
      </ul>
    </div>
  )
}

export default App
