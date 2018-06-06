package main

import (
  "os"
  "fmt"
  "path"
  "path/filepath"
  "strings"
  "crypto/md5"
  "io"
  "io/ioutil"
  "encoding/json"
)

func main() {
  const srcDir = "assets"
  const srcDirLen = len(srcDir) + 1
  const dstDir = "assets-hashed"

  fileMap := make(map[string]string)

  checkError(os.RemoveAll(dstDir))

  checkError(filepath.Walk(srcDir, func(filePath string, info os.FileInfo, err error) error {
    checkError(err)

    if info.IsDir() {
      return nil
    }

    trimmedPath := filePath[srcDirLen:]
    ext := path.Ext(trimmedPath)
    base := strings.TrimSuffix(trimmedPath, ext)
    hash := fileMd5(filePath)
    hashedTrimmedPath := base + "-" + hash[0:6] + ext
    hashedLocalPath := dstDir + "/" + hashedTrimmedPath
    hashedRemotePath := "/" + srcDir + "/" + hashedTrimmedPath
    newDir := path.Dir(hashedLocalPath)
    fileMap[trimmedPath] = hashedRemotePath

    checkError(os.MkdirAll(newDir, 0755))
    checkError(os.Link(filePath, hashedLocalPath))

    return nil
  }))

  fileMapJson, err := json.MarshalIndent(fileMap, "", "  ")
  checkError(err)

  checkError(ioutil.WriteFile(dstDir + "/fileMap.json", fileMapJson, 0444))
}

func fileMd5(filePath string) string {
  f, err := os.Open(filePath)
  checkError(err)

  defer f.Close()

  h := md5.New()
  _, err = io.Copy(h, f)
  checkError(err)

  return fmt.Sprintf("%x", h.Sum(nil))
}

func checkError(err error) {
  if err != nil {
    panic(err)
  }
}
