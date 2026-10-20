import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { MasterdataPage } from '../modules/masterdata';
import { ConstraintsPage } from '../modules/constraints';
import { AuditPage } from '../modules/audit';
import { NotificationsPage } from '../modules/notifications';
import { JobsPage } from '../modules/jobs';
import { MonitoringPage } from '../modules/monitoring';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/masterdata" replace /> },
  { path: 'masterdata', element: <MasterdataPage /> },
  { path: 'constraints', element: <ConstraintsPage /> },
  { path: 'audit', element: <AuditPage /> },
  { path: 'notifications', element: <NotificationsPage /> },
  { path: 'jobs', element: <JobsPage /> },
  { path: 'monitoring', element: <MonitoringPage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
