# Complex Story Templates

CSF3 story templates for components requiring render functions, decorators, or advanced configuration.

## Component with Custom Render Function

Use when the component needs wrapper elements or custom setup that cannot be expressed through args alone.

```tsx
import type { ArgTypes, Meta, StoryObj } from '@storybook/react-vite';

import { makeToast, Toast, Toaster } from '../main';

type Story = StoryObj<typeof Toast>;

const meta: Meta<typeof Toast> = {
  title: 'Components/Toast',
  component: Toast,
  tags: ['autodocs'],
  args: {
    label: 'Amazing toast',
    actionLabel: 'Action',
  },
};

export default meta;

const render = (args: ArgTypes<typeof Toast>) => (
  <div>
    <Toaster />
    <button type="button" onClick={() => makeToast(args)}>
      show toast
    </button>
  </div>
);

export const Error: Story = {
  render,
  args: { variant: 'error' },
};

export const Success: Story = {
  render,
  args: { variant: 'success' },
};
```

Key points:
- Extract shared `render` function when multiple stories use the same layout
- Import `ArgTypes` for typing the render function parameter
- `render` is defined outside the story object for reusability

## Component with Context Provider Decorators

Use when the component requires React context providers to render properly.

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';

import { searchAirlines, searchLocations } from '../../../../data';
import { SearchFormProvider } from '../../SearchFormContext';
import { JourneyForm } from './JourneyForm';

type Story = StoryObj<typeof JourneyForm>;

const meta: Meta<typeof JourneyForm> = {
  title: 'Shopping/JourneyForm',
  component: JourneyForm,
  tags: ['autodocs'],
  args: {
    cityPairs: [
      {
        origin: { code: 'MIA' },
        destination: { code: 'GRU' },
        date: new Date(),
      },
    ],
    onChange: () => {},
  },
  decorators: [
    Story => (
      <SearchFormProvider searchLocations={searchLocations} searchAirlines={searchAirlines}>
        <Story />
      </SearchFormProvider>
    ),
  ],
};

export default meta;

export const Primary: Story = {};
```

Key points:
- Provider wrapping goes in `decorators`, NOT in `render`
- Mock data imported from data modules
- `Story` component is rendered inside the provider via JSX `<Story />`

## Component with Figma Link and Visual Regression

Use for stable, design-system components linked to Figma.

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';

import type { Leg } from '../../data';
import { bookingPrice, flightDetails } from '../../data';
import { BookingTotalPrice, FlightDetails } from '../main';

const meta: Meta<typeof FlightDetails<Leg>> = {
  title: 'Booking/FlightDetails',
  component: FlightDetails,
  tags: ['autodocs', 'visual-regression'],
  args: {
    ...flightDetails,
    priceContainer: (
      <BookingTotalPrice.Root {...bookingPrice}>
        <BookingTotalPrice.Passengers />
      </BookingTotalPrice.Root>
    ),
  },
  parameters: {
    design: {
      type: 'figma',
      url: 'https://www.figma.com/file/...',
    },
  },
  globals: {
    backgrounds: { value: 'gray' },
  },
};

export default meta;

type Story = StoryObj<typeof FlightDetails>;

export const Primary: Story = {};
```

Key points:
- Generic component typed as `Meta<typeof FlightDetails<Leg>>`
- `'visual-regression'` tag added alongside `'autodocs'`
- `parameters.design` links to Figma for design reference
- `globals.backgrounds` overrides the background for all stories in this file
- Complex JSX can be passed as args when needed
