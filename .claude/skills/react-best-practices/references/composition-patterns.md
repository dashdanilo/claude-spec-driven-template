# Composition Patterns

Strategies for combining components to build complex UIs from simple pieces.

## Children Prop (Basic Composition)

The simplest composition — pass JSX as children:

```tsx
interface CardProps {
  children: React.ReactNode;
  className?: string;
}

function Card({ children, className }: CardProps) {
  return <div className={className}>{children}</div>;
}

// Usage
<Card>
  <h2>Title</h2>
  <p>Content goes here</p>
</Card>
```

**When to use**: Wrapping content with layout/styling. The parent doesn't need to know about children's shape.

## Compound Components (Context-Based)

A set of related components sharing implicit state via Context. The parent orchestrates, children consume.

```tsx
// --- Context ---
interface AccordionContextValue {
  openItems: Set<string>;
  toggle: (id: string) => void;
}

const AccordionContext = createContext<AccordionContextValue | null>(null);

function useAccordion() {
  const ctx = useContext(AccordionContext);
  if (!ctx) throw new Error('Accordion.* must be used within <Accordion>');
  return ctx;
}

// --- Root ---
interface AccordionProps {
  children: React.ReactNode;
  defaultOpen?: string[];
}

function Accordion({ children, defaultOpen = [] }: AccordionProps) {
  const [openItems, setOpenItems] = useState(() => new Set(defaultOpen));
  const toggle = useCallback((id: string) => {
    setOpenItems(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }, []);

  return (
    <AccordionContext.Provider value={{ openItems, toggle }}>
      <div role="region">{children}</div>
    </AccordionContext.Provider>
  );
}

// --- Item ---
function AccordionItem({ id, children }: { id: string; children: React.ReactNode }) {
  const { openItems } = useAccordion();
  return <div data-state={openItems.has(id) ? 'open' : 'closed'}>{children}</div>;
}

// --- Trigger ---
function AccordionTrigger({ id, children }: { id: string; children: React.ReactNode }) {
  const { toggle } = useAccordion();
  return <button onClick={() => toggle(id)}>{children}</button>;
}

// --- Content ---
function AccordionContent({ id, children }: { id: string; children: React.ReactNode }) {
  const { openItems } = useAccordion();
  if (!openItems.has(id)) return null;
  return <div role="region">{children}</div>;
}

// --- Attach as static properties ---
Accordion.Item = AccordionItem;
Accordion.Trigger = AccordionTrigger;
Accordion.Content = AccordionContent;

// --- Usage ---
<Accordion defaultOpen={['faq-1']}>
  <Accordion.Item id="faq-1">
    <Accordion.Trigger id="faq-1">Question 1</Accordion.Trigger>
    <Accordion.Content id="faq-1">Answer 1</Accordion.Content>
  </Accordion.Item>
</Accordion>
```

**When to use**: Related components that share state (Tabs, Accordion, Select, Menu). Consumers arrange children freely.

## Slots Pattern

Named insertion points — when you need structured composition beyond a single `children`:

```tsx
interface PageLayoutProps {
  header: React.ReactNode;
  sidebar: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

function PageLayout({ header, sidebar, children, footer }: PageLayoutProps) {
  return (
    <div className="layout">
      <header>{header}</header>
      <aside>{sidebar}</aside>
      <main>{children}</main>
      {footer && <footer>{footer}</footer>}
    </div>
  );
}

// Usage
<PageLayout
  header={<NavBar />}
  sidebar={<SideMenu />}
  footer={<FooterLinks />}
>
  <ArticleContent />
</PageLayout>
```

**When to use**: Layouts with multiple named regions. Clearer than multiple children with type checking.

## Render Props

Pass a function that receives data and returns JSX. Useful when the parent owns data but consumer controls rendering:

```tsx
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  renderEmpty?: () => React.ReactNode;
}

function List<T>({ items, renderItem, renderEmpty }: ListProps<T>) {
  if (items.length === 0) {
    return <>{renderEmpty?.() ?? <p>No items</p>}</>;
  }
  return <ul>{items.map((item, i) => <li key={i}>{renderItem(item, i)}</li>)}</ul>;
}

// Usage
<List
  items={users}
  renderItem={(user) => <UserCard user={user} />}
  renderEmpty={() => <EmptyState message="No users found" />}
/>
```

**When to use**: Generic containers where the consumer decides how to render each item. Prefer over HOCs for render-time flexibility.

## Pattern Selection

```
Fixed structure, single content area → children prop
Related components sharing hidden state → compound components
Multiple named content areas → slots (named props)
Consumer controls rendering of data → render prop
```
