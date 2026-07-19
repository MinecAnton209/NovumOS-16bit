import { visit } from 'unist-util-visit';
import type { Root } from 'mdast';
import type { MdxJsxFlowElement } from 'mdast-util-mdx-jsx';

/**
 * Remark plugin that converts ```mermaid fenced code blocks into
 * <Mermaid chart="..." /> component calls.
 */
export function remarkMermaid(): (tree: Root) => void {
  return (tree: Root) => {
    // First, collect all mermaid code blocks
    const nodes: { node: any; index: number; parent: any }[] = [];

    visit(tree, 'code', (node: any, index: number, parent: any) => {
      if (node.lang === 'mermaid') {
        nodes.push({ node, index, parent });
      }
    });

    // Process in reverse order to preserve indices
    for (const { node, index, parent } of nodes.reverse()) {
      const mdxElement: MdxJsxFlowElement = {
        type: 'mdxJsxFlowElement',
        name: 'Mermaid',
        attributes: [
          {
            type: 'mdxJsxAttribute',
            name: 'chart',
            value: node.value,
          },
        ],
        children: [],
        data: {
          _mdxExplicitJsx: true,
        },
      };

      parent.children.splice(index, 1, mdxElement);
    }
  };
}
