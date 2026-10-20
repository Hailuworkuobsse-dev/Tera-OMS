import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { DashboardPage } from '../modules/money-saved';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/dashboard" replace /> },
  { path: 'dashboard', element: <DashboardPage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
