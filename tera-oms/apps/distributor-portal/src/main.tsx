import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { AppRouter } from './app/routes';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProviders><AppRouter /></AppProviders>
  </React.StrictMode>
);
