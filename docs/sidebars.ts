import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'intro',
    'installation',
    'features',
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/editor-guide',
        'guides/mufi-repl',
        'guides/quick-start-repl',
        'guides/troubleshooting',
        'guides/distribution',
        'guides/distribution-quickstart',
        'guides/ci-code-signing',
        'guides/versioning',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      link: {
        type: 'doc',
        id: 'architecture',
      },
      items: [
        'architecture/metal-pipeline',
        'architecture/metal-implementation',
        'architecture/memory-safety',
        'architecture/linking',
      ],
    },
  ],
};

export default sidebars;
