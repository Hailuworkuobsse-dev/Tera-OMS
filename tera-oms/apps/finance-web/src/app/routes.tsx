import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom';
import { AppLayout } from './AppLayout';
import { FinancePage } from '../modules/finance';
const router = createBrowserRouter([{ path: '/', element: <AppLayout />, children: [
  { index: true, element: <Navigate to="/finance" replace /> },
  { path: 'finance', element: <FinancePage /> },
] }]);
export function AppRouter() { return <RouterProvider router={router} />; }
