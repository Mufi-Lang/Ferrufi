import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Metal-Accelerated',
    description: (
      <>
        Built on Metal for 60+ FPS text rendering and a fluid macOS experience.
        Leverages the power of Apple GPU for near-instantaneous interactions.
      </>
    ),
  },
  {
    title: 'Mufi Integration',
    description: (
      <>
        Native support for the Mufi language, including a high-performance REPL,
        integrated LSP for diagnostics, and syntax highlighting.
      </>
    ),
  },
  {
    title: 'Native macOS IDE',
    description: (
      <>
        A lightweight, security-scoped environment that feels like a permanent
        part of your macOS workflow. Adheres strictly to Apple design patterns.
      </>
    ),
  },
];

function Feature({title, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}