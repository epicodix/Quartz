import { Root as HTMLRoot, Element } from "hast"
import { QuartzTransformerPlugin } from "../types"
import { visit } from "unist-util-visit"

export const FirstImage: QuartzTransformerPlugin = () => {
  return {
    name: "FirstImage",
    htmlPlugins() {
      return [
        () => {
          return (tree: HTMLRoot, file) => {
            // frontmatter에 socialImage가 있으면 그걸 우선 사용
            if (file.data.frontmatter?.socialImage) {
              file.data.firstImage = file.data.frontmatter.socialImage
              return
            }

            // HTML AST에서 첫 번째 img 태그 찾기
            visit(tree, "element", (node: Element) => {
              if (file.data.firstImage) return
              if (node.tagName === "img" && node.properties?.src) {
                file.data.firstImage = node.properties.src as string
              }
            })
          }
        },
      ]
    },
  }
}

declare module "vfile" {
  interface DataMap {
    firstImage: string | undefined
  }
}
