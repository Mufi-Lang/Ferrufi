import type {ReactNode} from 'react';
import React, {useState} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function InstallPill() {
  const [copied, setCopied] = useState(false);
  const command = 'curl -sSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install.sh | bash';

  const handleCopy = () => {
    navigator.clipboard.writeText(command);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="installPill" onClick={handleCopy}>
      <span className="installPillCode">curl -sSL ... | bash</span>
      <span className={clsx('installPillButton', copied && 'copied')}>
        {copied ? 'Copied!' : 'Copy'}
      </span>
    </div>
  );
}

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <div className="row" style={{ alignItems: 'center' }}>
          <div className="col col--7">
            <Heading as="h1" className="hero__title" style={{ textAlign: 'left' }}>
              {siteConfig.title}
            </Heading>
            <p className="hero__subtitle" style={{ textAlign: 'left', marginBottom: '2rem' }}>
              High-performance, Metal-accelerated IDE for the Mufi programming language.
            </p>
            <div className={styles.buttons} style={{ justifyContent: 'flex-start', gap: '1rem' }}>
              <Link
                className="button button--secondary button--lg"
                to="/docs/installation">
                Get Started 🚀
              </Link>
              <Link
                className="button button--outline button--lg"
                to="/docs/intro"
                style={{ color: 'white', borderColor: 'white' }}>
                View Docs
              </Link>
            </div>
            <InstallPill />
          </div>
          <div className="col col--5">
            <div style={{ 
              background: '#1e1e1e', 
              borderRadius: '12px', 
              padding: '1.5rem', 
              boxShadow: '0 20px 50px rgba(0,0,0,0.4)',
              border: '1px solid #333',
              textAlign: 'left'
            }}>
              <div style={{ display: 'flex', gap: '6px', marginBottom: '1rem' }}>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ff5f56' }}></div>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ffbd2e' }}></div>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#27c93f' }}></div>
              </div>
              <pre style={{ margin: 0, background: 'none', border: 'none', color: '#d4d4d4' }}>
                <code>{`fun fibonacci(n) {
  if n <= 1 {
    return n;
  }
  return fibonacci(n - 1) + fibonacci(n - 2);
}

var result = fibonacci(10);
print("Fib(10) = " + str(result));`}</code>
              </pre>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}

function TechnicalFeatureSection() {
  return (
    <section style={{ padding: '5rem 0', background: 'var(--ifm-background-surface-color)' }}>
      <div className="container">
        <div className="row" style={{ alignItems: 'center' }}>
          <div className="col col--6">
            <Heading as="h2">GPU-Accelerated Rendering</Heading>
            <p>
              Ferrufi bypasses traditional CPU-bound text rendering. By leveraging Apple's <strong>Metal</strong> API, 
              every glyph, cursor animation, and selection highlight is rendered directly on the GPU.
            </p>
            <ul style={{ listStyle: 'none', padding: 0 }}>
              <li>✅ <strong>60+ FPS</strong> consistent performance</li>
              <li>✅ <strong>Zero-Latency</strong> typing experience</li>
              <li>✅ <strong>Fluid Animations</strong> using GPU interpolation</li>
            </ul>
          </div>
          <div className="col col--6">
             <div style={{ 
               padding: '2rem', 
               background: 'linear-gradient(45deg, #007aff, #5856d6)', 
               borderRadius: '20px',
               color: 'white',
               textAlign: 'center',
               fontWeight: 'bold',
               fontSize: '1.2rem'
             }}>
               Metal Renderer V2
               <div style={{ fontSize: '0.8rem', opacity: 0.8, marginTop: '0.5rem' }}>CoreText + Metal Shaders</div>
             </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function MufiSection() {
  return (
    <section style={{ padding: '5rem 0' }}>
      <div className="container">
        <div className="row" style={{ alignItems: 'center', flexDirection: 'row-reverse' }}>
          <div className="col col--6">
            <Heading as="h2">First-Class Mufi Support</Heading>
            <p>
              Designed specifically for the Mufi language. Get a full IDE experience without the bloat of
              traditional multi-language editors.
            </p>
            <div className="row">
              <div className="col col--6">
                <h3>Integrated REPL</h3>
                <p>Run code snippets instantly in an interactive side-panel.</p>
              </div>
              <div className="col col--6">
                <h3>Native LSP</h3>
                <p>Real-time diagnostics, hover info, and navigation powered by Swift.</p>
              </div>
            </div>
          </div>
          <div className="col col--6">
            <img src="img/logo.png" alt="Ferrufi Logo" style={{ width: '200px', display: 'block', margin: '0 auto' }} />
          </div>
        </div>
      </div>
    </section>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title} - High Performance IDE`}
      description="The native macOS IDE for the Mufi programming language, accelerated by Metal.">
      <HomepageHeader />
      <main>
        <TechnicalFeatureSection />
        <MufiSection />
        <section style={{ padding: '5rem 0', textAlign: 'center', borderTop: '1px solid var(--ifm-border-color)' }}>
          <div className="container">
            <Heading as="h2">Ready to build with Mufi?</Heading>
            <Link
              className="button button--primary button--lg"
              to="/docs/installation">
              Install Ferrufi for macOS
            </Link>
          </div>
        </section>
      </main>
    </Layout>
  );
}