// DaisyUI custom theme config for BankCORE
// Place in app/javascript/daisyui.theme.js and import in application.js

export const bankcoreTheme = {
  themes: [
    {
      bankcore: {
        'primary': '#2563eb',
        'secondary': '#f59e42',
        'accent': '#16a34a',
        'neutral': '#f3f4f6',
        'base-100': '#ffffff',
        'base-200': '#f3f4f6',
        'base-content': '#111827',
        'info': '#38bdf8',
        'success': '#16a34a',
        'warning': '#f59e42',
        'error': '#dc2626',
      }
    }
  ]
};

// To use: import { bankcoreTheme } from './daisyui.theme.js';
// Then apply to DaisyUI/Tailwind config or directly in markup as needed.
