import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import { AppProviders } from './app/AppProviders';
import { PortalPage } from './modules/portal/PortalPage';
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><AppProviders><PortalPage /></AppProviders></React.StrictMode>);
